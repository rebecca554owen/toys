// 国内DNS服务器
const domesticNameservers = [
  "https://dns.alidns.com/dns-query",  // 阿里
  "https://doh.pub/dns-query"          // 腾讯
];

// 国外DNS服务器
const foreignNameservers = [
  "https://dns.cloudflare.com/dns-query",  // Cloudflare 
  "https://dns.google/dns-query"           // Google
];

// DNS配置
const dnsConfig = {
  enable: true,
  listen: "0.0.0.0:1053",
  "prefer-h3": false,
  ipv6: true,
  "use-system-hosts": false,  // true or false
  "cache-algorithm": "arc",
  "enhanced-mode": "fake-ip",
  "fake-ip-range": "172.29.0.1/16",
  "fake-ip-filter": [
    // 本地主机/设备
    "+.lan",
    "+.local",
    // Windows网络检测
    "+.msftconnecttest.com",
    "+.msftncsi.com",
    // QQ/微信快速登录
    "localhost.ptlogin2.qq.com",
    "localhost.sec.qq.com",
    // 微信快速登录检测失败
    "localhost.work.weixin.qq.com",
    // 时间同步
    "time.*.com",
    "ntp.*.com"
  ],
  "default-nameserver": ["119.29.29.29"],
  nameserver: [...domesticNameservers],
  "proxy-server-nameserver": [...domesticNameservers],
  "nameserver-policy": {
    "geosite:private,cn,geolocation-cn": domesticNameservers,
    "geosite:google,youtube,telegram,gfw,geolocation-!cn": foreignNameservers
  }
};

// 规则配置
const rules = [
  // 自定义规则
  "DOMAIN,lan.freewife.online,DIRECT",
  "DOMAIN-SUFFIX,freewife.online,节点选择",
  "DOMAIN-SUFFIX,googleapis.cn,节点选择", // Google服务
  "DOMAIN-SUFFIX,gstatic.com,节点选择", // Google静态资源
  // 代理规则
  "GEOIP,lan,DIRECT,no-resolve",
  "GEOSITE,youtube,节点选择",
  "GEOSITE,google,节点选择",
  "GEOSITE,github,节点选择",
  "GEOSITE,telegram,Telegram",
  "GEOSITE,CN,DIRECT",
  "GEOSITE,geolocation-!cn,节点选择",
  "GEOIP,google,节点选择",
  "GEOIP,telegram,Telegram",
  "GEOIP,CN,DIRECT",
  // 兜底规则
  "MATCH,节点选择"
];

// 代理提供者配置
const proxyProviders = {
  "provider1": {
    type: "http",
    interval: 3600,
    url: "https://raw.githubusercontents.com/rebecca554owen/toys/main/yaml.yaml",
    path: "./airport.yaml"
  }
};

// 正则表达式定义
const hongKongRegex = /香港|HK|Hong|🇭🇰/i;
const taiwanRegex = /台湾|TW|Taiwan|Wan|🇨🇳|🇹🇼/i;
const singaporeRegex = /新加坡|狮城|SG|Singapore|🇸🇬/i;
const japanRegex = /日本|JP|Japan|🇯🇵/i;
const americaRegex = /美国|US|United States|America|🇺🇸/;
const othersRegex = /^(?!.*(?:香港|HK|Hong|🇭🇰|台湾|TW|Taiwan|Wan|🇨🇳|🇹🇼|新加坡|SG|Singapore|狮城|🇸🇬|日本|JP|Japan|🇯🇵|美国|US|States|America|🇺🇸|自动|故障|流量|官网|套餐|机场|订阅|年|月)).*$/;
const allRegex = /^(?!.*(?:自动|故障|流量|官网|套餐|机场|订阅|年|月|失联|频道)).*$/;

// 根据正则表达式获取代理
function getProxiesByRegex(config, regex) {
  return config.proxies
    .filter((e) => regex.test(e.name))
    .map((e) => e.name);
}

// 代理组通用配置
const groupBaseOption = {
  interval: 300,
  timeout: 1000,
  url: "https://www.gstatic.com/generate_204",
  lazy: true,
  "max-failed-times": 3,
  hidden: false
};

// 主函数
function main(config) {
  // 添加 proxy-providers 配置
  config["proxy-providers"] = proxyProviders;

  // 验证代理配置
  const proxyCount = config?.proxies?.length ?? 0;
  const proxyProviderCount = typeof config?.["proxy-providers"] === "object"
    ? Object.keys(config["proxy-providers"]).length
    : 0;

  if (proxyCount === 0 && proxyProviderCount === 0) {
    throw new Error("配置文件中未找到任何代理");
  }

  // 按地区分类代理
  const hongKongProxies = getProxiesByRegex(config, hongKongRegex);
  const taiwanProxies = getProxiesByRegex(config, taiwanRegex);
  const singaporeProxies = getProxiesByRegex(config, singaporeRegex);
  const japanProxies = getProxiesByRegex(config, japanRegex);
  const americaProxies = getProxiesByRegex(config, americaRegex);
  const othersProxies = getProxiesByRegex(config, othersRegex);

  // 代理组配置
  config["proxy-groups"] = [
    {
      ...groupBaseOption,
      name: "节点选择",
      type: "select",
      proxies: ["延迟选优", "故障转移", "relay转发", "前置节点", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg"
    },
    {
      ...groupBaseOption,
      name: "前置节点",
      type: "select",
      proxies: ["HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/cloudflare.svg"
    },
    {
      ...groupBaseOption,
      name: "出口节点",
      type: "select",
      proxies: [],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/link.svg"
    },
    {
      ...groupBaseOption,
      name: "relay转发",
      type: "relay",
      proxies: ["前置节点", "出口节点"],
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg"
    },
    {
      ...groupBaseOption,
      name: "延迟选优",
      type: "url-test",
      tolerance: 50,
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/speed.svg"
    },
    {
      ...groupBaseOption,
      name: "故障转移",
      type: "fallback",
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/ambulance.svg"
    },
    {
      ...groupBaseOption,
      name: "Telegram",
      type: "select",
      proxies: ["节点选择", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/telegram.svg"
    },
    {
      ...groupBaseOption,
      name: "微软服务",
      type: "select",
      proxies: ["DIRECT", "节点选择", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/microsoft.svg"
    },
    {
      ...groupBaseOption,
      name: "AI",
      type: "select",
      proxies: ["节点选择", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/chatgpt.svg"
    },
    {
      ...groupBaseOption,
      name: "HongKong",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/hk.svg",
      proxies: hongKongProxies.length > 0 ? hongKongProxies : ["DIRECT"]
    },
    {
      ...groupBaseOption,
      name: "TaiWan",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/tw.svg",
      proxies: taiwanProxies.length > 0 ? taiwanProxies : ["DIRECT"]
    },
    {
      ...groupBaseOption,
      name: "Singapore",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/sg.svg",
      proxies: singaporeProxies.length > 0 ? singaporeProxies : ["DIRECT"]
    },
    {
      ...groupBaseOption,
      name: "Japan",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/jp.svg",
      proxies: japanProxies.length > 0 ? japanProxies : ["DIRECT"]
    },
    {
      ...groupBaseOption,
      name: "America",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/us.svg",
      proxies: americaProxies.length > 0 ? americaProxies : ["DIRECT"]
    },
    // 其他地区
    {
      ...groupBaseOption,
      name: "Others",
      type: "select",
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/unknown.svg",
      proxies: othersProxies.length > 0 ? othersProxies : ["DIRECT"]
    }
  ];
  // 覆盖原配置中rules配置
  config["rules"] = rules;

  // 覆盖原配置中DNS配置
  config["dns"] = dnsConfig;

  // 返回修改后的配置
  return config;

}
