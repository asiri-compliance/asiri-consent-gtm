___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Asiri Consent",
  "categories": [
    "PRIVACY",
    "TAG_MANAGEMENT"
  ],
  "brand": {
    "id": "brand_dummy",
    "displayName": "Asiri Compliance Ltd"
  },
  "description": "Sets every consent type to denied before any other tag, loads the Asiri consent script, and updates Google Consent Mode when a visitor chooses.",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "sourceId",
    "displayName": "Source id",
    "simpleValueType": true,
    "help": "The source id from Asiri, Consent, Install. Letters, numbers and underscores.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^[A-Za-z0-9_]{1,64}$"
        ],
        "errorMessage": "Use the source id exactly as Asiri shows it."
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "publishableKey",
    "displayName": "Publishable key",
    "simpleValueType": true,
    "help": "Starts with pk_live_ or pk_test_. A secret key (sk_) never goes here.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^pk_(live|test)_[A-Za-z0-9]+$"
        ],
        "errorMessage": "The publishable key starts with pk_live_ or pk_test_."
      }
    ]
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "regionGroups",
    "displayName": "Region groups",
    "help": "Optional. Each row sets the starting state for the listed regions, for example GB, DE, FR or US-CA. Everything not listed starts denied. A row with only country codes is set first and a row with state or province codes after it, so the most specific row wins.",
    "simpleTableColumns": [
      {
        "defaultValue": "",
        "displayName": "Regions (ISO codes, comma separated)",
        "name": "regions",
        "type": "TEXT",
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          }
        ]
      },
      {
        "defaultValue": "denied",
        "displayName": "Ad storage",
        "name": "ad_storage",
        "type": "SELECT",
        "selectItems": [
          {
            "value": "denied",
            "displayValue": "Denied"
          },
          {
            "value": "granted",
            "displayValue": "Granted"
          }
        ]
      },
      {
        "defaultValue": "denied",
        "displayName": "Ad user data",
        "name": "ad_user_data",
        "type": "SELECT",
        "selectItems": [
          {
            "value": "denied",
            "displayValue": "Denied"
          },
          {
            "value": "granted",
            "displayValue": "Granted"
          }
        ]
      },
      {
        "defaultValue": "denied",
        "displayName": "Ad personalisation",
        "name": "ad_personalization",
        "type": "SELECT",
        "selectItems": [
          {
            "value": "denied",
            "displayValue": "Denied"
          },
          {
            "value": "granted",
            "displayValue": "Granted"
          }
        ]
      },
      {
        "defaultValue": "denied",
        "displayName": "Analytics storage",
        "name": "analytics_storage",
        "type": "SELECT",
        "selectItems": [
          {
            "value": "denied",
            "displayValue": "Denied"
          },
          {
            "value": "granted",
            "displayValue": "Granted"
          }
        ]
      },
      {
        "defaultValue": "denied",
        "displayName": "Functionality storage",
        "name": "functionality_storage",
        "type": "SELECT",
        "selectItems": [
          {
            "value": "denied",
            "displayValue": "Denied"
          },
          {
            "value": "granted",
            "displayValue": "Granted"
          }
        ]
      },
      {
        "defaultValue": "denied",
        "displayName": "Personalisation storage",
        "name": "personalization_storage",
        "type": "SELECT",
        "selectItems": [
          {
            "value": "denied",
            "displayValue": "Denied"
          },
          {
            "value": "granted",
            "displayValue": "Granted"
          }
        ]
      }
    ]
  },
  {
    "type": "SELECT",
    "name": "consentMode",
    "displayName": "Consent Mode",
    "selectItems": [
      {
        "value": "basic",
        "displayValue": "Basic"
      },
      {
        "value": "advanced",
        "displayValue": "Advanced"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "basic",
    "help": "Match the mode you chose in Asiri. Whether Google tags fire before a choice is set on each tag's consent settings, and the signed configuration holds the mode."
  },
  {
    "type": "CHECKBOX",
    "name": "adsDataRedaction",
    "checkboxText": "Redact ads data while ad storage is denied (ads_data_redaction)",
    "simpleValueType": true,
    "defaultValue": true
  },
  {
    "type": "CHECKBOX",
    "name": "urlPassthrough",
    "checkboxText": "Pass ad click information in page URLs while ad storage is denied (url_passthrough)",
    "simpleValueType": true,
    "defaultValue": false
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

var setDefaultConsentState = require('setDefaultConsentState');
var updateConsentState = require('updateConsentState');
var injectScript = require('injectScript');
var callInWindow = require('callInWindow');
var copyFromWindow = require('copyFromWindow');
var setInWindow = require('setInWindow');
var createQueue = require('createQueue');
var gtagSet = require('gtagSet');
var logToConsole = require('logToConsole');
var makeString = require('makeString');

// The pinned release. bin/gen-release.js rewrites this line and the inject_script permission together.
var SCRIPT_URL = 'https://edge.asiri.ng/c/v0.1.0/asiri.js';
var WAIT_FOR_UPDATE = 500;
var TYPES = [
  'ad_storage',
  'ad_user_data',
  'ad_personalization',
  'analytics_storage',
  'functionality_storage',
  'personalization_storage'
];
// Which Asiri categories decide each Consent Mode type (the script's default mapping).
var MAPPING = {
  ad_storage: ['marketing'],
  ad_user_data: ['marketing'],
  ad_personalization: ['marketing'],
  analytics_storage: ['analytics'],
  functionality_storage: ['necessary'],
  personalization_storage: ['preferences']
};
var ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
var ALNUM = ALPHA + '0123456789';
var ID_CHARS = ALNUM + 'abcdefghijklmnopqrstuvwxyz_';
var KEY_CHARS = ALNUM + 'abcdefghijklmnopqrstuvwxyz';

function onlyFrom(text, alphabet) {
  for (var i = 0; i < text.length; i++) {
    if (alphabet.indexOf(text.charAt(i)) < 0) return false;
  }
  return true;
}

// The same checks the script makes (^[A-Za-z0-9_]{1,64}$ and ^pk_(live|test)_[A-Za-z0-9]+$). A bad value is never
// handed over, and a secret key (sk_) never reaches the page.
function validSourceId(id) {
  return typeof id === 'string' && id.length >= 1 && id.length <= 64 && onlyFrom(id, ID_CHARS);
}

function validKey(key) {
  if (typeof key !== 'string') return false;
  var rest = key.indexOf('pk_live_') === 0 ? key.substring(8) : key.indexOf('pk_test_') === 0 ? key.substring(8) : '';
  return rest.length > 0 && onlyFrom(rest, KEY_CHARS);
}

// Two letters, or two letters, a hyphen and one to three letters or digits (GB, DE, US-CA).
function validRegion(code) {
  var parts = code.split('-');
  if (parts.length > 2) return false;
  if (parts[0].length !== 2 || !onlyFrom(parts[0], ALPHA)) return false;
  if (parts.length === 2) {
    if (parts[1].length < 1 || parts[1].length > 3 || !onlyFrom(parts[1], ALNUM)) return false;
  }
  return true;
}

function regionsOf(row) {
  var out = [];
  var raw = makeString(row.regions || '').split(',');
  for (var i = 0; i < raw.length; i++) {
    var code = raw[i].trim().toUpperCase();
    if (code === '') continue;
    if (!validRegion(code)) {
      logToConsole('Asiri Consent: region "' + code + '" is not an ISO code and was ignored.');
      continue;
    }
    if (out.indexOf(code) < 0) out.push(code);
  }
  return out;
}

function hasSubdivision(regions) {
  for (var i = 0; i < regions.length; i++) {
    if (regions[i].indexOf('-') >= 0) return true;
  }
  return false;
}

// Anything that is not exactly "granted" is denied.
function stateOf(row, region) {
  var state = {};
  for (var i = 0; i < TYPES.length; i++) {
    state[TYPES[i]] = row[TYPES[i]] === 'granted' ? 'granted' : 'denied';
  }
  state.wait_for_update = WAIT_FOR_UPDATE;
  if (region) state.region = region;
  return state;
}

function setDefaults(groups) {
  var countryOnly = [];
  var withSubdivision = [];
  for (var i = 0; i < groups.length; i++) {
    var regions = regionsOf(groups[i]);
    if (regions.length === 0) continue;
    if (hasSubdivision(regions)) withSubdivision.push({ row: groups[i], regions: regions });
    else countryOnly.push({ row: groups[i], regions: regions });
  }
  // Most specific last: country rows first, then state and province rows.
  var ordered = countryOnly.concat(withSubdivision);
  for (var j = 0; j < ordered.length; j++) {
    setDefaultConsentState(stateOf(ordered[j].row, ordered[j].regions));
  }
  // The rest of the world: everything denied.
  setDefaultConsentState(stateOf({}, null));
}

// Turns the visitor's categories into Consent Mode types. A type is only sent when the script reported one of
// its categories, so a partial report leaves the other types as they were.
function mapUpdate(categories) {
  var update = {};
  var count = 0;
  for (var i = 0; i < TYPES.length; i++) {
    var sources = MAPPING[TYPES[i]];
    var known = false;
    var granted = false;
    for (var j = 0; j < sources.length; j++) {
      var value = categories[sources[j]];
      if (value === undefined || value === null) continue;
      known = true;
      if (value === true) granted = true;
    }
    if (known) {
      update[TYPES[i]] = granted ? 'granted' : 'denied';
      count++;
    }
  }
  return count > 0 ? update : null;
}

function listener(state) {
  if (!state || !state.categories) return;
  var update = mapUpdate(state.categories);
  if (update) updateConsentState(update);
}

// 1. Defaults first, before anything else on the page can read consent.
setDefaults(data.regionGroups || []);

if (data.adsDataRedaction === true || data.urlPassthrough === true) {
  var flags = {};
  if (data.adsDataRedaction === true) flags.ads_data_redaction = true;
  if (data.urlPassthrough === true) flags.url_passthrough = true;
  gtagSet(flags);
}

createQueue('dataLayer')({
  event: 'asiri_gtm_ready',
  asiri_consent_mode: data.consentMode === 'advanced' ? 'advanced' : 'basic'
});

// 2. The source and key. injectScript cannot set data-source or data-key on the tag, so they are left on the page
// as asiriConfig, which the script reads when its own tag has none. Nothing else is handed over.
var sourceId = makeString(data.sourceId).trim();
var publishableKey = makeString(data.publishableKey).trim();
if (!validSourceId(sourceId) || !validKey(publishableKey)) {
  logToConsole('Asiri Consent: the source id or the publishable key is not in the form Asiri gives. The script was not loaded and every consent type stays denied.');
  data.gtmOnFailure();
  return;
}
setInWindow('asiriConfig', { source: sourceId, key: publishableKey }, true);

// 3. The pinned script. GTM's injectScript cannot carry an integrity hash: SRI is not available through GTM.
injectScript(
  SCRIPT_URL,
  function () {
    callInWindow('asiri.onChange', listener);
    // A choice made on an earlier page is already in place when the script is ready.
    if (copyFromWindow('asiri.ready') === true) {
      listener({ categories: copyFromWindow('asiri.categories') });
    }
    data.gtmOnSuccess();
  },
  function () {
    logToConsole('Asiri Consent: the script did not load. Every consent type stays denied.');
    data.gtmOnFailure();
  },
  SCRIPT_URL
);


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_consent",
        "versionId": "1"
      },
      "param": [
        {
          "key": "consentTypes",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_user_data"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_personalization"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "analytics_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "functionality_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "personalization_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://edge.asiri.ng/c/v0.1.0/asiri.js"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "asiri.onChange"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "asiri.ready"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "asiri.categories"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "asiriConfig"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "dataLayer"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "write_data_layer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "ads_data_redaction"
              },
              {
                "type": 1,
                "string": "url_passthrough"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Defaults are denied with the wait, before the script is injected
  code: |-
    var order = [];
    var defaults = [];
    mock('setDefaultConsentState', function(o) { order.push('default'); defaults.push(o); });
    mock('injectScript', function(url, ok, fail) { order.push('inject'); ok(); });
    mock('callInWindow', function() {});
    mock('copyFromWindow', function() { return undefined; });
    mock('setInWindow', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    runCode(mockData);
    assertThat(order).isEqualTo(['default', 'inject']);
    assertThat(defaults.length).isEqualTo(1);
    assertThat(defaults[0].wait_for_update).isEqualTo(500);
    assertThat(defaults[0].ad_storage).isEqualTo('denied');
    assertThat(defaults[0].ad_user_data).isEqualTo('denied');
    assertThat(defaults[0].ad_personalization).isEqualTo('denied');
    assertThat(defaults[0].analytics_storage).isEqualTo('denied');
    assertThat(defaults[0].functionality_storage).isEqualTo('denied');
    assertThat(defaults[0].personalization_storage).isEqualTo('denied');
    assertApi('gtmOnSuccess').wasCalled();
- name: A region group is set before the global default, and the state rows come last
  code: |-
    var seen = [];
    mock('setDefaultConsentState', function(o) { seen.push(o); });
    mock('injectScript', function(url, ok, fail) { ok(); });
    mock('callInWindow', function() {});
    mock('copyFromWindow', function() { return undefined; });
    mock('setInWindow', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    var d = mockData;
    d.regionGroups = [
      { regions: 'US-CA', ad_storage: 'granted', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'granted', functionality_storage: 'granted', personalization_storage: 'granted' },
      { regions: 'gb, DE', ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied', analytics_storage: 'denied', functionality_storage: 'denied', personalization_storage: 'denied' }
    ];
    runCode(d);
    assertThat(seen.length).isEqualTo(3);
    assertThat(seen[0].region).isEqualTo(['GB', 'DE']);
    assertThat(seen[1].region).isEqualTo(['US-CA']);
    assertThat(seen[1].ad_storage).isEqualTo('granted');
    assertThat(seen[2].region).isUndefined();
    assertThat(seen[2].ad_storage).isEqualTo('denied');
- name: The injected script is the pinned URL
  code: |-
    var injected = [];
    mock('setDefaultConsentState', function() {});
    mock('injectScript', function(url, ok, fail) { injected.push(url); ok(); });
    mock('callInWindow', function() {});
    mock('copyFromWindow', function() { return undefined; });
    mock('setInWindow', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    runCode(mockData);
    assertThat(injected).isEqualTo(['https://edge.asiri.ng/c/v0.1.0/asiri.js']);
- name: A choice with analytics allowed updates analytics_storage only
  code: |-
    var listener = null;
    var updates = [];
    mock('setDefaultConsentState', function() {});
    mock('injectScript', function(url, ok, fail) { ok(); });
    mock('callInWindow', function(path, fn) { if (path === 'asiri.onChange') listener = fn; });
    mock('copyFromWindow', function() { return undefined; });
    mock('setInWindow', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    mock('updateConsentState', function(o) { updates.push(o); });
    runCode(mockData);
    listener({ categories: { analytics: true } });
    assertThat(updates).isEqualTo([{ analytics_storage: 'granted' }]);
- name: A script that fails to load leaves the defaults denied and reports failure
  code: |-
    mock('setDefaultConsentState', function() {});
    mock('injectScript', function(url, ok, fail) { fail(); });
    mock('callInWindow', function() {});
    mock('copyFromWindow', function() { return undefined; });
    mock('setInWindow', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    runCode(mockData);
    assertApi('gtmOnFailure').wasCalled();
- name: The source and key are left on the page for the script before it is injected
  code: |-
    var order = [];
    var set = null;
    mock('setDefaultConsentState', function() {});
    mock('setInWindow', function(k, v) { order.push('set'); set = { k: k, v: v }; });
    mock('injectScript', function(url, ok, fail) { order.push('inject'); ok(); });
    mock('callInWindow', function() {});
    mock('copyFromWindow', function() { return undefined; });
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    runCode(mockData);
    assertThat(order).isEqualTo(['set', 'inject']);
    assertThat(set.k).isEqualTo('asiriConfig');
    assertThat(set.v.source).isEqualTo('src_example');
    assertThat(set.v.key).isEqualTo('pk_test_example');
- name: A secret key is refused and the script is not loaded
  code: |-
    var injected = 0;
    var set = 0;
    mock('setDefaultConsentState', function() {});
    mock('setInWindow', function() { set++; });
    mock('injectScript', function(url, ok, fail) { injected++; ok(); });
    mock('callInWindow', function() {});
    mock('copyFromWindow', function() { return undefined; });
    mock('createQueue', function() { return function() {}; });
    mock('logToConsole', function() {});
    var d = mockData;
    d.publishableKey = 'sk_live_abc';
    runCode(d);
    assertThat(injected).isEqualTo(0);
    assertThat(set).isEqualTo(0);
    assertApi('gtmOnFailure').wasCalled();
setup: |-
  var mockData = {
    sourceId: 'src_example',
    publishableKey: 'pk_test_example',
    regionGroups: [],
    consentMode: 'basic',
    adsDataRedaction: true,
    urlPassthrough: false
  };


___NOTES___

Asiri Consent for Google Tag Manager, by Asiri Compliance Ltd.

Fire this tag first: trigger Consent Initialization, All Pages.

SRI is not available through GTM. The injectScript API cannot carry an integrity attribute, so the script is pinned by its exact versioned address in the inject_script permission. A changed template is needed to load any other address, and the signed configuration still protects what the script does.

The source id and publishable key reach the script as the page object asiriConfig, written just before the script is injected (injectScript cannot set data-source or data-key). The script uses it only when its own tag has neither attribute.

Each new script release needs a new version of this template, because the address is pinned in the permission.

Permissions: "Accesses consent state" (each consent type, write only), inject_script (one exact address), access_globals (execute asiri.onChange, read asiri.ready and asiri.categories, write asiriConfig, read and write dataLayer), write_data_layer (ads_data_redaction and url_passthrough only), logging (debug only).


