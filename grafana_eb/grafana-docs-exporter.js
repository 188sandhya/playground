// usage: define path and run it with $ node grafana_doc_exporter.js
// and copy output to desired file

const path = "../../errorbudget-grafana/docs/http_api_mds/sources/http_api";

var fs = require("fs");

var exportDocs = (path) => {
  var files = fs.readdirSync(path);
  for (file of files) {
    const data = openFile(path + "/" + file);
    fillPaths(data);
  }
  return openapiTemplate;
};

var openFile = (file) => {
  var markdown = fs.readFileSync(file, "utf8");
  return markdown.split("\n");
};

var fillPaths = (lines) => {
  const methodregex = /(POST|DELETE|GET|PUT|PATCH)/m;

  var entry = {};
  for (var line of lines) {
    //header for description
    if (line.startsWith("##")) {
      entry.description = line.slice(2);
    }

    //get api method and url
    if (line.startsWith("`") && !line.startsWith("```")) {
      //remove ``
      line = line.split("`").join("");
      // get method type
      method = line.match(methodregex);
      if (method.length > 0) {
        [entry.url, entry.params] = getUrlAndParameters(line);
        entry.method = method[0].toLowerCase();
      }
    }
    if (line.startsWith("HTTP/1.1")) {
      var r = /\d+/g;
      entry.responseCode = line.slice("HTTP/1.1".length).match(r);
      addEntry(entry);
    }
  }
};

var getUrlAndParameters = (url) => {
  var params = [];
  url = url.slice(method[0].length).trim();
  url = url.includes("?") ? url.slice(0, url.indexOf("?")) : url;
  if (url.includes(":id")) {
    url = url.replace(":id", "{id}");
    params = [
      {
        name: "id",
        in: "path",
        description: "ID",
        required: true,
        schema: {
          type: "integer",
        },
      },
    ];
  }
  if (url.includes(":uid")) {
    url = url.replace(":uid", "{uid}");
    params = [
      {
        name: "uid",
        in: "path",
        description: "uuid",
        required: true,
        schema: {
          type: "string",
        },
      },
    ];
  }
  return [url, params];
};

var addEntry = (entry) => {
  if (!openapiTemplate.paths[entry.url]) {
    openapiTemplate.paths[entry.url] = {};
  }
  openapiTemplate.paths[entry.url][entry.method] = {
    description: entry.description,
    tags: [],
    summary: entry.description,
    parameters: entry.params,
    responses: {
      [entry.responseCode]: {
        description: "Example response",
      },
    },
  };
};

var openapiTemplate = {
  openapi: "3.0.0",
  info: {
    description: "Grafana with OMA improvements",
    title: "OMA grafana",
    contact: {
      name: "OMA Team",
      "x-teams":
        "https://teams.microsoft.com/l/channel/19%3a9dcdba3b28144dd99339b438a4fb6041%40thread.skype/DXSupport_OMA?groupId=5db0b21c-0aca-418e-ba3a-14fd04f0fa9a&tenantId=64322308-09a9-47a3-8c1c-b82871d60568",
      "x-slack": "#error_budget_support",
    },
    license: {
      name: "​",
    },
    version: "1.0",
    "x-keywords": "errorbudget oma observe measure anaylze slo utilization",
    "x-related-masterdata": "proxy, analytics",
    "x-activated-countries": ["ALL"],
    "x-solution": "OMA",
    "x-scope": "metro",
  },
  paths: {},
  security: [],
  servers: [
    {
      url: "oma.metro.digital",
    },
  ],
};

console.log(JSON.stringify(exportDocs("./http_api_mds")));
