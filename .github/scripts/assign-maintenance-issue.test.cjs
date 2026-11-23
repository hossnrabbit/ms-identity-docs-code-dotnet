const assert = require('node:assert/strict');
const { test } = require('node:test');
const assignIssue = require('./assign-maintenance-issue.cjs');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const workflow = readFileSync(join(__dirname, '../workflows/release-maintenance.yml'), 'utf8');
const issueScript = workflow.match(/^          script: \|\r?\n([\s\S]*)$/m);
assert.ok(issueScript, 'The shared release workflow must contain its issue script.');
const runIssueScript = new AsyncFunction('github', 'context', 'core', 'require', 'process',
  issueScript[1].replace(/^            /gm, ''));

function fixture(overrides = {}, timeline = [[]]) {
  const requests = [];
  const notices = [];
  const issue = {
    state: 'open',
    user: { login: 'github-actions[bot]' },
    body: `<!-- sample-maintenance:${'a'.repeat(64)} -->`,
    assignees: [],
    ...overrides
  };
  const input = {
    context: { repo: { owner: 'hossnrabbit', repo: 'ms-identity-docs-code-dotnet' } },
    issueNumber: 42,
    core: { notice: message => notices.push(message) },
    github: {
      rest: { issues: { get: async () => ({ data: issue }), listEventsForTimeline: 'timeline' } },
      paginate: { iterator: async function* () {
        for (const events of timeline) yield { data: events };
      } },
      request: async (route, parameters) => {
        requests.push({ route, parameters });
        return { data: { assignees: [{ login: 'copilot-swe-agent[bot]' }] } };
      }
    }
  };
  return { input, requests, notices };
}

test('assigns an open workflow issue to the bounded custom agent', async () => {
  const { input, requests } = fixture();
  await assignIssue(input);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].route, 'POST /repos/{owner}/{repo}/issues/{issue_number}/assignees');
  assert.equal(requests[0].parameters.issue_number, 42);
  assert.deepEqual(requests[0].parameters.assignees, ['copilot-swe-agent[bot]']);
  assert.deepEqual(requests[0].parameters.agent_assignment, {
    target_repo: 'hossnrabbit/ms-identity-docs-code-dotnet',
    base_branch: 'main',
    custom_agent: 'sample-implementer'
  });
  assert.equal(requests[0].parameters.request.retries, 0);
});

for (const overrides of [
  { state: 'closed' },
  { assignees: [{ login: 'copilot-swe-agent[bot]' }] }
]) {
  test(`skips ${JSON.stringify(overrides)}`, async () => {
    const { input, requests } = fixture(overrides);
    await assignIssue(input);
    assert.equal(requests.length, 0);
  });
}

test('checks later timeline pages to avoid restarting a previously assigned agent', async () => {
  const { input, requests } = fixture({}, [[], [
    { event: 'assigned', assignee: { login: 'copilot-swe-agent[bot]' } }
  ]]);
  await assignIssue(input);
  assert.equal(requests.length, 0);
});

for (const overrides of [
  { user: { login: 'someone-else' } },
  { body: 'No maintenance marker' },
  { pull_request: { url: 'https://example.test/pr' } }
]) {
  test(`rejects unrelated issue ${JSON.stringify(overrides)}`, async () => {
    const { input, requests } = fixture(overrides);
    await assert.rejects(assignIssue(input), /Only workflow-created/);
    assert.equal(requests.length, 0);
  });
}

test('rejects another repository or an invalid issue number', async () => {
  const { input, requests } = fixture();
  input.context.repo.owner = 'another-owner';
  await assert.rejects(assignIssue(input), /sandbox repository/);
  input.context.repo.owner = 'hossnrabbit';
  input.issueNumber = NaN;
  await assert.rejects(assignIssue(input), /valid release issue/);
  assert.equal(requests.length, 0);
});

test('fails visibly if GitHub silently ignores the assignee', async () => {
  const { input } = fixture();
  input.github.request = async () => ({ data: { assignees: [] } });
  await assert.rejects(assignIssue(input), /did not confirm/);
});

test('propagates API failures without retrying assignment', async () => {
  const { input } = fixture();
  let attempts = 0;
  input.github.request = async () => {
    attempts += 1;
    throw new Error('API unavailable');
  };
  await assert.rejects(assignIssue(input), /API unavailable/);
  assert.equal(attempts, 1);
});

function releaseFixture(packageId, upstream) {
  const calls = [];
  const outputs = {};
  const pages = [[]];
  const env = {
    RELEASE_PACKAGE: packageId,
    RELEASE_VERSION: '4.10.0',
    RELEASE_NOTES_URL: `https://github.com/${upstream}/releases/tag/4.10.0`,
    DRY_RUN: 'false',
    EVENT_KEY: ''
  };
  const context = { repo: { owner: 'hossnrabbit', repo: 'ms-identity-docs-code-dotnet' } };
  const core = { notice: () => {}, setOutput: (name, value) => { outputs[name] = value; } };
  const github = {
    rest: { issues: {
      listForRepo: 'issues',
      create: async parameters => {
        calls.push({ kind: 'create', parameters });
        return { data: { number: 42, html_url: 'https://example.test/42' } };
      }
    } },
    paginate: { iterator: async function* (endpoint, parameters) {
      assert.equal(endpoint, 'issues');
      assert.equal(parameters.state, 'all');
      calls.push({ kind: 'list' });
      for (const data of pages) yield { data };
    } },
    request: async () => { throw new Error('The shared workflow must never assign an agent.'); }
  };
  return { calls, outputs, pages, env, run: () => runIssueScript(github, context, core, require, { env }) };
}

for (const [packageId, upstream] of [
  ['Microsoft.Identity.Client', 'AzureAD/microsoft-authentication-library-for-dotnet'],
  ['Microsoft.Identity.Web', 'AzureAD/microsoft-identity-web'],
  ['Microsoft.Identity.Web.UI', 'AzureAD/microsoft-identity-web']
]) {
  test(`shared workflow dry run has no GitHub calls for ${packageId}`, async () => {
    const state = releaseFixture(packageId, upstream);
    state.env.DRY_RUN = 'true';
    await state.run();
    assert.deepEqual(state.calls, []);
  });

  test(`shared workflow creates and deduplicates closed ${packageId} issues`, async () => {
    const state = releaseFixture(packageId, upstream);
    await state.run();
    assert.equal(state.outputs['issue-number'], 42);
    const created = state.calls.find(call => call.kind === 'create').parameters;
    assert.ok(created.body.includes(`repository must match https://github.com/${upstream}.git`));
    assert.ok(created.body.includes(`-Package ${packageId}`));
    assert.ok(created.body.includes('targeting test/msal-harness-e2e, never main or upstream'));
    const marker = created.body.split('\n')[0];
    state.pages.push([
      { number: 99, state: 'closed', user: { login: 'someone-else' }, body: marker },
      { number: 42, state: 'closed', user: { login: 'github-actions[bot]' }, body: marker, html_url: 'https://example.test/42' }
    ]);
    await state.run();
    assert.equal(state.calls.filter(call => call.kind === 'create').length, 1);
    assert.equal(state.outputs['issue-number'], 42);
  });
}

for (const [field, value] of [
  ['RELEASE_PACKAGE', 'Untrusted.Package'],
  ['RELEASE_VERSION', '4.10.0-preview'],
  ['RELEASE_NOTES_URL', 'https://github.com/AzureAD/microsoft-identity-web/releases/tag/4.10.0'],
  ['EVENT_KEY', 'incorrect-key']
]) {
  test(`shared workflow rejects invalid ${field} before GitHub calls`, async () => {
    const state = releaseFixture('Microsoft.Identity.Client', 'AzureAD/microsoft-authentication-library-for-dotnet');
    state.env[field] = value;
    await assert.rejects(state.run());
    assert.deepEqual(state.calls, []);
  });
}