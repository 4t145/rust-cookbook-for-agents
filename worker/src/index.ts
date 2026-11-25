import { AGENTS_EN, AGENTS_ZH, INSTALL_SH } from "./generated.ts";

const REPO_URL = "https://github.com/4t145/rust-cookbook-for-agents";

const ROUTES: Readonly<Record<string, { readonly body: string; readonly contentType: string }>> = Object.freeze({
  "/install.sh": {
    body: INSTALL_SH,
    contentType: "text/x-shellscript; charset=utf-8",
  },
  "/AGENTS.md": {
    body: AGENTS_EN,
    contentType: "text/markdown; charset=utf-8",
  },
  "/AGENTS.zh-CN.md": {
    body: AGENTS_ZH,
    contentType: "text/markdown; charset=utf-8",
  },
});

export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed\n", {
        status: 405,
        headers: {
          Allow: "GET, HEAD",
          "Content-Type": "text/plain; charset=utf-8",
        },
      });
    }

    if (url.pathname === "/") {
      return Response.redirect(REPO_URL, 302);
    }

    const route = ROUTES[url.pathname];
    if (!route) {
      return new Response("Not Found\n", {
        status: 404,
        headers: { "Content-Type": "text/plain; charset=utf-8" },
      });
    }

    return new Response(request.method === "HEAD" ? null : route.body, {
      status: 200,
      headers: {
        "Content-Type": route.contentType,
        "Cache-Control": "public, max-age=300",
        "X-Content-Type-Options": "nosniff",
      },
    });
  },
};
