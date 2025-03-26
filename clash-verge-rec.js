// 国内DNS服务器
const domesticNameservers = [
  "https://dns.alidns.com/dns-query#h3=true", // 阿里
  "https://doh.pub/dns-query" // 腾讯
];

// 国外DNS服务器
const foreignNameservers = [
  "https://dns.cloudflare.com/dns-query", // Cloudflare
  "https://dns.google/dns-query" // Google
];

// DNS配置
const dnsConfig = {
  enable: true,
  listen: "0.0.0.0:1053",
  "prefer-h3": false,
  ipv6: true,
  "use-system-hosts": false, // true or false
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
    "ntp.*.com",
    // 小米应用市场
    "+.market.xiaomi.com"
  ],
  "default-nameserver": ["119.29.29.29"], // 只能使用纯 IP 地址
  nameserver: [...domesticNameservers],
  "proxy-server-nameserver": [...domesticNameservers],
  "nameserver-policy": {
    "geosite:private,cn,geolocation-cn": domesticNameservers,
    "geosite:google,youtube,telegram,gfw,geolocation-!cn": foreignNameservers
  }
};

// 规则集通用配置
const ruleProviderCommon = {
  type: "http",
  behavior: "domain",
  format: "yaml",
  interval: 86400 // 24小时更新
};

// 规则集配置
const ruleProviders = {
  apple: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/apple.txt",
    path: "./rulesets/loyalsoldier/apple.yaml"
  },
  applications: {
    ...ruleProviderCommon,
    behavior: "classical",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/applications.txt",
    path: "./rulesets/loyalsoldier/applications.yaml"
  },
  cncidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt",
    path: "./rulesets/loyalsoldier/cncidr.yaml"
  },
  direct: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt",
    path: "./rulesets/loyalsoldier/direct.yaml"
  },
  gfw: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt",
    path: "./rulesets/loyalsoldier/gfw.yaml"
  },
  google: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/google.txt",
    path: "./rulesets/loyalsoldier/google.yaml"
  },
  icloud: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/icloud.txt",
    path: "./rulesets/loyalsoldier/icloud.yaml"
  },
  lancidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt",
    path: "./rulesets/loyalsoldier/lancidr.yaml"
  },
  openai: {
    ...ruleProviderCommon,
    behavior: "classical",
    url: "https://fastly.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/OpenAI/OpenAI.yaml",
    path: "./rulesets/openai.yaml"
  },
  claude: {
    ...ruleProviderCommon,
    behavior: "classical",
    url: "https://fastly.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Claude/Claude.yaml",
    path: "./rulesets/claude.yaml"
  },
  ai: {
    ...ruleProviderCommon,
    behavior: "classical",
    url: "https://github.com/MetaCubeX/meta-rules-dat/raw/refs/heads/meta/geo/geosite/classical/category-ai-!cn.yaml",
    path: "./rulesets/claude.yaml"
  },
  private: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/private.txt",
    path: "./rulesets/loyalsoldier/private.yaml"
  },
  proxy: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt",
    path: "./rulesets/loyalsoldier/proxy.yaml"
  },
  reject: {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt",
    path: "./rulesets/loyalsoldier/reject.yaml"
  },
  telegramcidr: {
    ...ruleProviderCommon,
    behavior: "ipcidr",
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/telegramcidr.txt",
    path: "./rulesets/loyalsoldier/telegramcidr.yaml"
  },
  "tld-not-cn": {
    ...ruleProviderCommon,
    url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/tld-not-cn.txt",
    path: "./rulesets/loyalsoldier/tld-not-cn.yaml"
  }
};

// 规则配置
const rules = [
  // 自定义规则
  "DOMAIN,lan.freewife.online,DIRECT",
  "DOMAIN-SUFFIX,freewife.online,节点选择",
  "DOMAIN-SUFFIX,googleapis.cn,节点选择", // Google服务
  "DOMAIN-SUFFIX,gstatic.com,节点选择", // Google静态资源
  "DOMAIN-SUFFIX,xn--ngstr-lra8j.com,节点选择", // Google Play

  // Loyalsoldier 规则集
  "RULE-SET,applications,DIRECT",
  "RULE-SET,private,DIRECT",
  "RULE-SET,reject,REJECT",
  "RULE-SET,icloud,微软服务",
  "RULE-SET,apple,苹果服务",
  "RULE-SET,google,谷歌服务",
  "RULE-SET,openai,OpenAI",
  "RULE-SET,claude,Claude",
  "RULE-SET,ai,OpenAI",
  "RULE-SET,tld-not-cn,节点选择",
  "RULE-SET,gfw,节点选择",
  "RULE-SET,proxy,节点选择",
  "RULE-SET,direct,DIRECT",
  "RULE-SET,lancidr,DIRECT",
  "RULE-SET,cncidr,DIRECT",
  "RULE-SET,telegramcidr,电报消息",
  
  // GEOIP规则
  "GEOIP,LAN,DIRECT",
  "GEOIP,CN,DIRECT",
  
  // 兜底规则
  "MATCH,节点选择"
];

// 代理组通用配置
const groupBaseOption = {
  interval: 300,
  timeout: 1000,
  url: "https://www.gstatic.com/generate_204",
  lazy: true,
  "max-failed-times": 3,
  hidden: false
};

// 代理提供者配置
const proxyProviders = {
  "本地节点": {
    type: "file",
    interval: 3600,
    path: "D:\\yaml.yaml" // 只能用 yaml格式 或者 url链接格式 节点
  }/*,
  "机场节点": {
    type: "http",
    interval: 3600,
    url: "https://raw.githubusercontents.com/rebecca554owen/toys/main/yaml.yaml",
    path: ".\\ariport.yaml",
    filter: "(?i)香港" 
  }*/
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

// 主函数
function main(config) {
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
  const allProxies = getProxiesByRegex(config, allRegex);

  // 代理组配置
  config["proxy-groups"] = [
    // 主选择组
    {
      ...groupBaseOption,
      name: "节点选择",
      type: "select",
      proxies: ["relay", "前置节点", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg"
    },
    // 前置节点组
    {
      ...groupBaseOption,
      name: "前置节点",
      type: "select",
      proxies: ["延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/cloudflare.svg"
    },
    // 出口节点组
    {
      ...groupBaseOption,
      name: "出口节点",
      type: "select",
      proxies: [],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/link.svg"
    },
    // 中继组
    {
      ...groupBaseOption,
      name: "relay",
      type: "relay",
      proxies: ["前置节点", "出口节点"],
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg"
    },
    // 延迟测试组
    {
      ...groupBaseOption,
      name: "延迟选优",
      type: "url-test",
      tolerance: 50,
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/speed.svg"
    },
    // 故障转移组
    {
      ...groupBaseOption,
      name: "故障转移",
      type: "fallback",
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/ambulance.svg"
    },
    // 负载均衡组
    {
      ...groupBaseOption,
      name: "负载均衡(散列)",
      type: "load-balance",
      strategy: "consistent-hashing",
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/merry_go.svg"
    },
    {
      ...groupBaseOption,
      name: "负载均衡(轮询)",
      type: "load-balance",
      strategy: "round-robin",
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/balance.svg"
    },
    // 服务专用组
    {
      ...groupBaseOption,
      name: "谷歌服务",
      type: "select",
      proxies: ["节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/google.svg"
    },
    {
      ...groupBaseOption,
      name: "国外媒体",
      type: "select",
      proxies: ["节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/youtube.svg"
    },
    {
      ...groupBaseOption,
      name: "电报消息",
      type: "select",
      proxies: ["节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/telegram.svg"
    },
    {
      ...groupBaseOption,
      name: "微软服务",
      type: "select",
      proxies: ["DIRECT", "节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/microsoft.svg"
    },
    {
      ...groupBaseOption,
      name: "苹果服务",
      type: "select",
      proxies: ["DIRECT", "节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/apple.svg"
    },
    {
      ...groupBaseOption,
      name: "OpenAI",
      type: "select",
      proxies: ["节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/chatgpt.svg"
    },
    {
      ...groupBaseOption,
      name: "Claude",
      type: "select",
      proxies: ["节点选择", "延迟选优", "故障转移", "负载均衡(散列)", "负载均衡(轮询)", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/claude.svg"
    },
    // 香港地区
    {
      ...groupBaseOption,
      name: "HongKong",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/hk.svg",
      proxies: hongKongProxies.length > 0 ? hongKongProxies : ["DIRECT"]
    },
    // 台湾地区
    {
      ...groupBaseOption,
      name: "TaiWan",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/tw.svg",
      proxies: taiwanProxies.length > 0 ? taiwanProxies : ["DIRECT"]
    },
    // 新加坡
    {
      ...groupBaseOption,
      name: "Singapore",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/sg.svg",
      proxies: singaporeProxies.length > 0 ? singaporeProxies : ["DIRECT"]
    },
    // 日本
    {
      ...groupBaseOption,
      name: "Japan",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/jp.svg",
      proxies: japanProxies.length > 0 ? japanProxies : ["DIRECT"]
    },
    // 美国
    {
      ...groupBaseOption,
      name: "America",
      type: "select",
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/flags/us.svg",
      proxies: americaProxies.length > 0 ? americaProxies : ["DIRECT"]
    },
    // 其他
    {
      ...groupBaseOption,
      name: "Others",
      type: "select",
      hidden: true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/unknown.svg",
      proxies: othersProxies.length > 0 ? othersProxies : ["DIRECT"]
    }
];

  // 覆盖原配置中DNS配置
  config["dns"] = dnsConfig;

  // 将 proxy-providers 添加到配置中
  config["proxy-providers"] = proxyProviders;

  // 覆盖原配置中的规则
  config["rule-providers"] = ruleProviders;
  config["rules"] = rules;

  // 返回修改后的配置
  return config;

}
