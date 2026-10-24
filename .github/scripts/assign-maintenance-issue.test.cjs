const assert = require('node:assert/strict');
const { test } = require('node:test');
const assignIssue = require('./assign-maintenance-issue.cjs');

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