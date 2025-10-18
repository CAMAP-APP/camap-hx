# Neo modules integration

- Retrieve script URLs via `BridgeService.getNeoModuleScripts()` or template helper `View.getNeoModuleScripts`.
- Include the three bundles in the page: `runtime.js`, `vendors.js`, and `neo.js` (from the manifest URLs).
- Add a container element with a stable id (e.g., `<div id="my-module-root"></div>`).
- Initialize on DOMContentLoaded: `neo.createNeoModule('<id>', '<moduleName>', <props>)`.
- Pass only serializable props for stability; keep module state on the TS side.
