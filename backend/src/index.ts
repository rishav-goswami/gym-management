import app from "./server";
import { config } from "dotenv";
config();

const PORT = process.env.PORT || 3002;
// Start the Express Server
app.listen(PORT, (err?: unknown) => {
  if (err) throw err;
  console.log(`> Ready on http://localhost:${PORT}`);
});
