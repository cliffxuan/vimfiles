function handleRequest(req, res) {
  const id = req.params.id;
  const user = findUser(id);
  if (!user) {
    res.status(404).send('User not found');
    return;
  }
  res.json(user);
}