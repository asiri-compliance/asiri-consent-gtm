<p align="center"><img src="assets/asiri-mark.png" alt="Asiri" width="96" height="96"></p>

# Asiri Consent for Google Tag Manager

A community template that holds every consent type at denied until a visitor chooses, loads the Asiri consent script, and passes each choice to Google Consent Mode. Licensed under Apache-2.0.

## Install

1. In Tag Manager, open Templates, then Tag Templates, then Search Gallery. Choose Asiri Consent and Add to workspace.
2. Open Tags and choose New tag, then Asiri Consent. Paste your source id and your publishable key, both from Asiri, Consent, Install. The source id is letters, numbers and underscores. The key starts with `pk_live_` or `pk_test_`; a secret key (`sk_`) is refused and never goes here. Both are required: without them the script cannot record receipts.
3. Set the trigger to Consent Initialization, All Pages, so the tag fires before any other. Submit and publish.

## What it does

- Calls `setDefaultConsentState` with every type denied and `wait_for_update` of 500, once for each region group you add (country rows first, state or province rows after, so the most specific row wins), then once with no region for everywhere else.
- Checks the source id and publishable key against the same formats the script uses. If either is wrong, nothing is loaded, every type stays denied, and the tag reports failure.
- Leaves `asiriConfig = { source, key }` on the page with `setInWindow`, then loads `https://edge.asiri.ng/c/v0.1.0/asiri.js` with `injectScript`. `injectScript` cannot set `data-source` or `data-key` on the tag, so the script reads `asiriConfig` when its own tag has neither. The script then gets the same two inputs as the script-tag install and records receipts the same way. Attributes on the tag, where there are any, win over `asiriConfig`.
- Registers a listener with `asiri.onChange` and calls `updateConsentState` on each choice, so Tag Manager's built-in consent checks follow the visitor.

| Asiri category | Consent Mode types |
|---|---|
| marketing | ad_storage, ad_user_data, ad_personalization |
| analytics | analytics_storage |
| preferences | personalization_storage |
| necessary | functionality_storage |

## Permissions

Accesses consent state (each type, write only); inject_script for the one address above; access_globals to run `asiri.onChange`, read `asiri.ready` and `asiri.categories`, write `asiriConfig` (write only), and read and write `dataLayer`; write_data_layer for `ads_data_redaction` and `url_passthrough` only; logging in debug only.

## SRI is not available through GTM

GTM's `injectScript` cannot carry an integrity attribute, so a template cannot check the script's hash. Instead the script is pinned by its exact versioned address in the template's permission: a changed template is needed to load anything else, and the signed configuration still protects what the script does. Sites that need a hash check should use the plain script tag, which carries `integrity`.

Each new script release needs a new version of this template, because the address is pinned.

## What a Tag Manager install does not carry

The script tag can also set a custom data layer name, `data-headless`, a CSP nonce and `data-subject-token`. A tag template cannot set attributes, so none of these come through Tag Manager. The data layer is always `dataLayer`. A page that knows its signed-in visitor can still define `window.asiriSubjectToken` itself. Sites that need the others use the script tag.

The pinned script must be a release that reads `asiriConfig`; an older release loads and records nothing.

## Testing in a real Tag Manager container

Needs a Tag Manager container you can publish to, and a source id and publishable key from Asiri (a sandbox source for a sandbox run).

1. Import the template: Templates, Tag Templates, New, the three-dot menu, Import, choose `template.tpl`. For a sandbox run, first make a private copy of the file and replace the pinned address in two places (the `SCRIPT_URL` line and the `inject_script` permission) with the sandbox edge address, for example `https://edge.staging.asiri.ng/c/v<version>/asiri.js`. Open that address in a browser first to confirm the release exists there. Never publish the edited copy.
2. Create the tag: New tag, Asiri Consent. Paste the source id and publishable key. Trigger: Consent Initialization, All Pages.
3. Preview: Preview, enter a page that has no other Asiri script, and connect.
4. In the Tag Assistant summary, the tag should show Succeeded, and its Consent tab should show every type denied before any other tag.
5. In the page's browser dev tools, Console: `window.asiriConfig` returns `{ source, key }` with your values.
6. Network: a request to `/c/cfg/<your source id>/auto.json` returns 200, and the banner appears.
7. Choose Accept all or Reject all in the banner. A POST to the receipts route returns 201, and the tag's consent state updates in Tag Assistant.
8. Failure checks: set the key to an `sk_` value and preview again. The tag should show Failed, no script is requested, and every type stays denied.

If step 6 shows no request, the script release is older than the `asiriConfig` change. If the request returns 404, the source id is wrong for that environment.
