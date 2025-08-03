const express = require('express');
const app = express();
app.use(express.json());

app.get('/repos/:owner/:repo/issues/:issue_number', (req, res) => {
  console.log(`Mock intercepted: GET /repos/${req.params.owner}/${req.params.repo}/issues/${req.params.issue_number}`);
  console.log('Request headers:', JSON.stringify(req.headers));

  // Validate the Authorization header
  if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Unauthorized: Missing or invalid Bearer token' });
  }

  // Simulate response based on parameters
  if (
    req.params.owner === 'test-owner' &&
    req.params.repo === 'test-repo' &&
    req.params.issue_number === '1'
  ) {
    res.status(200).json({ assignees: [] });
  } else if (
    req.params.owner === 'test-owner' &&
    req.params.repo === 'test-repo' &&
    req.params.issue_number === '2'
  ) {
    res.status(200).json({ assignees: [{ login: 'test-user' }] });
  } else {
    res.status(404).json({ message: 'Issue not found' });
  }
});

app.post('/repos/:owner/:repo/issues/:issue_number/assignees', (req, res) => {
  console.log(`Mock intercepted: POST /repos/${req.params.owner}/${req.params.repo}/issues/${req.params.issue_number}/assignees`);
  console.log('Request body:', JSON.stringify(req.body));
  console.log('Request headers:', JSON.stringify(req.headers));

  // Validate the Authorization header
  if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Unauthorized: Missing or invalid Bearer token' });
  }

  // Validate the request body
  if (
    req.body.assignees &&
    Array.isArray(req.body.assignees) &&
    req.body.assignees.length > 0 &&
    req.params.owner === 'test-owner' &&
    req.params.repo === 'test-repo' &&
    req.params.issue_number === '1'
  ) {
    res.status(201).json({ assignees: [{ login: req.body.assignees[0] }] });
  } else {
    res.status(403).json({ message: 'Forbidden' });
  }
});

app.listen(3000, () => {
  console.log('Mock server listening on http://127.0.0.1:3000...');
});
