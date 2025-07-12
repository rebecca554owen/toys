// 国内DNS服务器
const domesticNameservers = [
  "system"
];

// 国外DNS服务器
const foreignNameservers = [
  "system"
];

// DNS配置
const dnsConfig = {
  enable: true,
  ipv6: true,
  listen: "0.0.0.0:1053",
  "enhanced-mode": "fake-ip",
  "fake-ip-range": "198.18.0.1/16",
  "fake-ip-filter": [
    // 本地主机/设备
    "+.lan",
    "+.local",
    // Windows网络检测
    "+.msftncsi.com",
    "+.msftconnecttest.com",
    // QQ/微信快速登录
    "localhost.sec.qq.com",
    "localhost.ptlogin2.qq.com",
    // 微信快速登录检测失败
    "localhost.work.weixin.qq.com",
    // 时间同步
    "ntp.*.com",
    "time.*.com",
    // geosite
    "geosite:cn",
    "geosite:private"
  ],
  nameserver: [...domesticNameservers],
  "default-nameserver": [...domesticNameservers],
  "proxy-server-nameserver": [...domesticNameservers],
  "nameserver-policy": {
    "geosite:private,cn,geolocation-cn": domesticNameservers,
    "geosite:google,youtube,telegram,gfw,geolocation-!cn": foreignNameservers
  }
};

// 规则配置
const rules = [
  // 自定义规则
  //  "geosite,category-ads-all,REJECT", 
  // 直连优先
  "GEOIP,lan,DIRECT,no-resolve",
  "GEOIP,cn,DIRECT",
  "GEOSITE,cn,DIRECT",
  // 特殊应用
  "GEOIP,telegram,Telegram",
  "GEOSITE,telegram,Telegram",
  "GEOSITE,category-ai-!cn,Ai",
  // 兜底规则
  "MATCH,节点选择"
];

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
  // 验证代理配置
  const proxyCount = config?.proxies?.length ?? 0;
  if (proxyCount === 0) {
    throw new Error("配置文件中未找到任何节点");
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
      proxies: ["前置节点","出口节点","HongKong","TaiWan","Singapore","Japan","America","Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/adjust.svg"
    },
    {
      ...groupBaseOption,
      name: "前置节点",
      type: "select",
      proxies: ["HongKong","TaiWan","Singapore","Japan","America"],
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
      name: "Ai",
      type: "select",
      proxies: ["节点选择","前置节点","出口节点","HongKong","TaiWan","Singapore","Japan","America","Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/chatgpt.svg"
    },
    {
      ...groupBaseOption,
      name: "Telegram",
      type: "select",
      proxies: ["节点选择","前置节点","出口节点","HongKong","TaiWan","Singapore","Japan","America","Others"],
      "include-all": true,
      icon: "https://fastly.jsdelivr.net/gh/clash-verge-rev/clash-verge-rev.github.io@main/docs/assets/icons/telegram.svg"
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
  // 覆盖原配置中 rules 配置
  config["rules"] = rules;

  // 覆盖原配置中 DNS 配置
  config["dns"] = dnsConfig;

  // 返回修改后的配置
  return config;

}