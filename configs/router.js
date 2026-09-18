// Model-name router for the dual-model stack (base Qwen3.8 on GPU 0, Swift on GPU 1).
//
// nginx cannot read a JSON body in plain config, so this njs function looks at the
// request's "model" field and returns the upstream name. Anything that is not a
// Swift request (including GET /v1/models, /health, /metrics) goes to the base
// replica, which keeps every existing client working unchanged.
//
// Loaded by qwen-router.conf via `js_import router.js`. `route` is a js_content handler,
// NOT a js_set variable: a variable used in proxy_pass is evaluated before nginx has read
// the request body, so requestText is empty there and every request falls through to
// base (seen live: a swift request answered 404 by the vLLM card). A content handler
// runs after the body is in memory; it then redirects internally to /_base or /_swift,
// which carry the ordinary streaming proxy_pass.
function upstream(r) {
    var body = r.requestText;
    if (body) {
        try {
            var m = JSON.parse(body).model || "";
            if (typeof m === "string" && m.toLowerCase().indexOf("swift") !== -1) {
                return "swift";
            }
        } catch (e) { /* not JSON: fall through to base */ }
    }
    return "base";
}

// GET /v1/models: both ids, so a client listing models sees the Swift arm too.
// Static on purpose: an njs subrequest fan-out would need internal locations and
// the ids are fixed by the launcher (SERVED_NAME) anyway.
function models(r) {
    var now = Math.floor(Date.now() / 1000);
    r.headersOut["Content-Type"] = "application/json";
    r.return(200, JSON.stringify({object: "list", data: [
        {id: "qwen3.8-27b", object: "model", created: now, owned_by: "vllm"},
        {id: "swift-qwen3.8-27b", object: "model", created: now, owned_by: "vllm"}
    ]}));
}

function route(r) {
    var target = "/_" + upstream(r) + r.uri;
    if (r.variables.args) { target += "?" + r.variables.args; }
    r.internalRedirect(target);
}

export default { upstream, models, route };
