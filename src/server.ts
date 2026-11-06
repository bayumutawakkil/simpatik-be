import { app } from "./app";
import { env } from "./config/env";

process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
});

process.on("uncaughtException", (error) => {
  console.error("Uncaught Exception:", error);
});

app.listen(env.PORT, () => console.log(`Server running on http://localhost:${env.PORT}`));
