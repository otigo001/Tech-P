const express = require("express");

const app = express();

const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "My Task API is working!"
  });
});

app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});

const tasks = [
  {
    id: 1,
    name: "Learn Node.js",
    completed: true
  },
  {
    id: 2,
    name: "Learn Docker",
    completed: false
  }
];

app.get("/tasks", (req, res) => {
  res.json(tasks);
});