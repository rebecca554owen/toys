/* 全局字体 */
 * {
  font-family: "微软雅黑" !important;
}

body[theme-mode="dark"] {
  --color-background: #2B2D30;
  --color-background-soft: #393B40;
  --color-background-mute: #393B40;
  --navbar-background: #2B2D30;
  --chat-background: #2B2D30;
  --chat-background-user: #393B40;
  --chat-background-assistant: #393B40;
  --chat-text-user: #FFFFFF;
  --chat-customize-collapse-background: #2B2D30;
  --chat-customize-codeHeader: #B0B3B8;
  --antd-arrow-background-color: #2B2D30;
  --list-item-border-radius: 8px;
  /* 划词助手 */
  --selection-toolbar-logo-display: none;
  --selection-toolbar-background: #2B2D30; 
  --selection-toolbar-box-shadow: none;
  --selection-toolbar-border-radius: 14px;
  --selection-toolbar-button-border-radius: 14px;
  /*自定义变量*/
  --color-card-main: #393B40;
  --color-card-head: #43454A;
  --color-background-sec: #2B2D30;
  --color-btn-main: #393B40;
  --chat-customize-box-shadow: rgba(0, 0, 0, 0.4) 6px 6px 12px, rgba(60, 60, 60, 0.4) -6px -6px 12px;
  --chat-customize-box-shadow2: rgba(0, 0, 0, 0.4) 6px 6px 12px, rgba(60, 60, 60, 0.4) -6px -6px 12px;
  --chat-customize-box-shadow3:
    inset 0.25rem 0.25rem 0.8rem #212326,
    inset -0.25rem -0.25rem 0.8rem #35373a,
    0 0.3rem 0.6rem rgba(0, 0, 0, 0.3);
  --chat-customize-box-shadow4:
    inset 0.2rem 0.2rem 0.6rem #2a2c30,
    inset -0.2rem -0.2rem 0.6rem #484a50,
    0 0 5px rgba(42, 44, 48, 0.4);
  --chat-customize-box-shadow5:
    inset 0.25rem 0.25rem 0.8rem #212326,
    inset -0.25rem -0.25rem 0.8rem #35373a,
    0 0.3rem 0.6rem rgba(0, 0, 0, 0.3);
  --btn-customize-box-shadow:
    inset 2px 2px 3px 0px rgba(100, 100, 100, 0.5),
    7px 7px 15px 0px rgba(0, 0, 0, 0.1),
    4px 4px 5px 0px rgba(0, 0, 0, 0.1);
}

body[theme-mode="light"] {
  --color-background: #FFFAE8;
  --color-background-soft: #E8DFC4;
  --color-background-mute: #E8DFC4;
  --navbar-background: #FFFAE8;
  --chat-background: #FFFAE8;
  --chat-background-user: #FFFAE8;
  --chat-background-assistant: #FFFAE8;
  --chat-text-user: #000;
  --chat-customize-collapse-background: #E8DFC4;
  --chat-customize-codeHeader: #9F9371;
  --antd-arrow-background-color: #FFFAE8;
  --list-item-border-radius: 8px;
  /* 划词助手 */
  --selection-toolbar-logo-display: none;
  --selection-toolbar-background: white;
  --selection-toolbar-box-shadow: none;
  --selection-toolbar-border-radius: 14px;
  --selection-toolbar-button-border-radius: 14px;
  /*自定义变量*/
  --color-card-main: #FFFAE8;
  --color-card-head: #E8DFC4;
  --color-background-sec: #E8DFC4;
  --color-btn-main: #FFFAE8;
  --chat-customize-box-shadow: 0.15rem 0.15rem 0.5rem #888;
  --chat-customize-box-shadow2:
    -1px -1px 5px 0px #fff,
    7px 7px 20px 0px #0003,
    4px 4px 5px 0px #0002;
  --chat-customize-box-shadow3:
    inset 0.1rem 0.1rem 0.2rem #d1c9b0,
    inset -0.1rem -0.1rem 0.2rem #ffffff,
    0.1rem 0.1rem 0.2rem rgba(200, 190, 160, 0.3);
  --chat-customize-box-shadow4:
    inset 0.2rem 0.2rem 0.6rem #d0c7ae,
    inset -0.2rem -0.2rem 0.6rem #fff7da,
    0 0 5px rgba(208, 199, 174, 0.4);
  --chat-customize-box-shadow5:
    inset 0.2rem 0.2rem 0.6rem #d0c7ae,
    inset -0.2rem -0.2rem 0.6rem #fff7da,
    0 0 5px rgba(208, 199, 174, 0.4);
  --btn-customize-box-shadow:
    inset 2px 2px 2px 0px rgba(255, 255, 255, .5),
    7px 7px 20px 0px rgba(0, 0, 0, .1),
    4px 4px 5px 0px rgba(0, 0, 0, .1);
}

/* ===== 输入栏 ===== */
.inputbar-container {
  border-radius: 12px;
  border: transparent;
  background-color: var(--chat-background-assistant) !important;
  box-shadow: var(--chat-customize-box-shadow);
}

/* ===== 侧边栏导航 ===== */
/* 平行tab按钮基础样式 */
.rc-virtual-list .ant-dropdown-trigger,
div[class^="TopicListItem-"],
div[class^="ProviderListItem-"] {
  background-color: transparent !important;
  border: transparent !important;
  box-shadow: none;
  position: relative;
  transition: all 0.3s ease;
}

/* 悬停状态字体样式 */
.rc-virtual-list .ant-dropdown-trigger:hover:not(.active) div[class^="AssistantName-"].text-nowrap,
div[class^="TopicListItem-"]:hover:not(.active),
div[class^="ProviderListItem-"]:hover:not(.active) div[class^="ProviderItemName-"].text-nowrap {
  color: #2EB372 !important;
  transition: color 0.3s ease;
}

/* 激活状态字体样式 */
.rc-virtual-list .ant-dropdown-trigger.active div[class^="AssistantName-"].text-nowrap,
div[class^="TopicListItem-"].active,
div[class^="ProviderListItem-"].active div[class^="ProviderItemName-"].text-nowrap {
  color: #00B96B !important;
  text-shadow: 0 0 0.5px rgba(0, 185, 107, 0.4);
}

/* 激活状态边框装饰 */
.rc-virtual-list .ant-dropdown-trigger.active:before,
.rc-virtual-list .ant-dropdown-trigger.active:after,
div[class^="TopicListItem-"].active:before,
div[class^="TopicListItem-"].active:after,
div[class^="ProviderListItem-"].active:before,
div[class^="ProviderListItem-"].active:after {
  content: '';
  position: absolute;
  height: 2px;
  width: 100%;
  background: var(--color-background-soft, #f0f0f0);
  box-shadow: var(--chat-customize-box-shadow2, 0 1px 2px rgba(0, 0, 0, 0.1));
  transition: 400ms ease all;
  pointer-events: none;
}

.rc-virtual-list .ant-dropdown-trigger.active:before,
div[class^="TopicListItem-"].active:before,
div[class^="ProviderListItem-"].active:before {
  top: 0;
  right: 0;
}

.rc-virtual-list .ant-dropdown-trigger.active:after,
div[class^="TopicListItem-"].active:after,
div[class^="ProviderListItem-"].active:after {
  bottom: 0;
  left: 0;
}

/* 非激活状态边框初始样式 */
.rc-virtual-list .ant-dropdown-trigger:not(.active):before,
.rc-virtual-list .ant-dropdown-trigger:not(.active):after,
div[class^="TopicListItem-"]:not(.active):before,
div[class^="TopicListItem-"]:not(.active):after,
div[class^="ProviderListItem-"]:not(.active):before,
div[class^="ProviderListItem-"]:not(.active):after {
  content: '';
  position: absolute;
  height: 2px;
  width: 0;
  background: var(--color-background-soft, #f0f0f0);
  box-shadow: var(--chat-customize-box-shadow2, 0 1px 2px rgba(0, 0, 0, 0.1));
  transition: 400ms ease all;
  pointer-events: none;
}

.rc-virtual-list .ant-dropdown-trigger:not(.active):before,
div[class^="TopicListItem-"]:not(.active):before,
div[class^="ProviderListItem-"]:not(.active):before {
  top: 0;
  right: 0;
}

.rc-virtual-list .ant-dropdown-trigger:not(.active):after,
div[class^="TopicListItem-"]:not(.active):after,
div[class^="ProviderListItem-"]:not(.active):after {
  bottom: 0;
  left: 0;
}

/* 悬停动画效果 */
.rc-virtual-list .ant-dropdown-trigger:hover:not(.active):before,
.rc-virtual-list .ant-dropdown-trigger:hover:not(.active):after,
div[class^="TopicListItem-"]:hover:not(.active):before,
div[class^="TopicListItem-"]:hover:not(.active):after,
div[class^="ProviderListItem-"]:hover:not(.active):before,
div[class^="ProviderListItem-"]:hover:not(.active):after {
  width: 100%;
  transition: 800ms ease all;
}

/* 删除消息按钮 */
.active .menu {
  background-color: transparent !important;
  border-radius: 30px;
}

.active .menu:hover {
  color: #ff0000 !important;
}

/* ===== 消息气泡框 ===== */
.bubble .message-content-container {
  border-radius: 12px;
  box-shadow: var(--chat-customize-box-shadow);
}

/* ===== 弹出框 ===== */
.ant-popover-inner {
  background: var(--chat-background-assistant) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
}

/* ===== 翻译相关组件 ===== */
div[class^="InputContainer-"],
div[class^="OutputContainer-"],
div[class^="HistoryContainner-"] {
  background: var(--chat-background-assistant) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
}

/* ===== 通知/消息组件 ===== */
.ant-notification-notice,
.ant-message-notice-content,
.ant-drawer-content {
  background: var(--chat-background-assistant) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
}

/* ===== 聊天历史 ===== */
.react-flow.dark {
  background: var(--chat-background-assistant) !important;
}

/* ===== 智能体/提示词相关 ===== */
.ant-modal .ant-modal-content,
div[class^="AgentCardContainer-"] {
  background: var(--chat-background-assistant) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
}

.ant-modal-confirm-content div[class^="AgentPrompt-"],
div[class^="CardInfo-"] {
  box-shadow: var(--chat-customize-box-shadow5) !important;
  background: var(--chat-customize-collapse-background) !important;
}

/* ===== 常规Tab按钮样式 ===== */
/* 基础样式 */
li[class^="MenuItem-"],
#content-container [class^="ListItemContainer-"],
.ant-segmented-group .ant-segmented-item-label {
  color: var(--chat-text-user) !important;
  border: 0 !important;
  transition: all 0.2s ease;
  box-sizing: border-box;
}

/* 激活状态 */
li[class^="MenuItem-"].active,
#content-container [class^="ListItemContainer-"].active {
  background-color: var(--color-background-mute);
  box-shadow: var(--chat-customize-box-shadow);
  transition: all 0.2s ease;
  border-radius: var(--list-item-border-radius);
}

/* 悬停状态 */
li[class^="MenuItem-"]:hover,
#content-container [class^="ListItemContainer-"]:hover {
  background-color: var(--color-background-mute);
  box-shadow: var(--chat-customize-box-shadow);
  transition: all 0.2s ease;
  border-radius: var(--list-item-border-radius);
}

.ant-segmented-group .ant-segmented-item-label[aria-selected="true"],
.ant-segmented-group .ant-segmented-item-label:hover {
  box-shadow: var(--chat-customize-box-shadow4) !important;
  background: var(--color-background-soft) !important;
  border-radius: var(--list-item-border-radius);
}

.ant-segmented .ant-segmented-item-focused {
  outline: transparent !important;
}

/* 侧边栏图标按钮 */
#app-sidebar [class^="Icon-"].active,
#app-sidebar [class^="Icon-"]:hover {
  box-shadow: var(--chat-customize-box-shadow3) !important;
  background: var(--chat-background) !important;
  transition: all 0.2s ease;
  border: none !important;
}

/* ===== 设置组件 ===== */
div[class^="ServerCard-"],
div[class^="SettingGroup-"] .ant-segmented,
div[class^="SettingContainer-"] div[class^="SettingGroup-"],
.ant-segmented.ant-segmented-shape-round {
  border-radius: var(--list-item-border-radius);
  background-color: var(--chat-background-assistant) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
  border: transparent !important;
}

.ant-segmented-thumb,
label.ant-segmented-item.ant-segmented-item-selected {
  background-color: transparent !important;
  border: transparent !important;
}

.ant-segmented-thumb-motion-appear-active {
  display: none !important;
}

/* 显示设置->显示的图标 */
div[class^="SettingGroup-"] div[class^="IconSection-"] {
  background-color: transparent !important;
}

div[class^="SettingGroup-"] div[class^="ProgramList-"],
div[class^="SettingGroup-"] div[class^="IconList-"] {
  background-color: var(--color-background-sec);
}

div[class^="SettingGroup-"] div[class^="ProgramItem-"],
div[class^="SettingGroup-"] div[class^="IconItem-"] {
  border-radius: var(--list-item-border-radius) !important;
  background-color: var(--color-card-main) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
  border: transparent !important;
}

/* mcp */
div[class^="SettingContainer-"] .ant-card {
  box-shadow: var(--chat-customize-box-shadow) !important;
  background-color: var(--chat-background-assistant) !important;
}

div[class^="SettingContainer-"] .ant-card .ant-card-head {
  background-color: var(--color-card-head) !important;
}

/* ===== 思考框 ===== */
/* 折叠面板头部 */
.ant-collapse-header {
  background-color: var(--color-card-head) !important;
  border-radius: 0 !important;
}

/* 折叠面板内容 */
.ant-collapse .ant-collapse-content {
  background-color: var(--chat-background-assistant) !important;
  border: transparent !important;
}

/* 折叠面板边框 */
.ant-collapse,
.ant-collapse-borderless {
  border: none !important;
}

.ant-collapse-item {
  border-radius: 12px !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
  overflow: hidden;
}

/* ===== 搜索框 ===== */
div[class^="NavbarContainer-"] .ant-input-affix-wrapper,
.ant-modal-body .ant-input-affix-wrapper,
.ant-modal-body .ant-input-affix-wrapper-focused {
  background-color: var(--color-background-mute) !important;
  box-shadow: var(--chat-customize-box-shadow4) !important;
  border: none;
  border-radius: 30px;
}

.ant-input-search-button {
  background: var(--color-btn-main) !important;
  box-shadow: var(--btn-customize-box-shadow) !important;
}

div[class^="SearchIcon-"] {
  background-color: transparent !important;
}

/* ===== 下拉选项单选框 ===== */
.ant-select .ant-select-selector {
  border: none !important;
  border-radius: var(--list-item-border-radius) !important;
  background-color: var(--color-background-soft) !important;
  box-shadow: var(--chat-customize-box-shadow4) !important;
}

/* active */
.ant-select-item-option.ant-select-item-option-active {
  border-radius: var(--list-item-border-radius) !important;
  background-color: var(--color-background-soft) !important;
  box-shadow: var(--chat-customize-box-shadow4) !important;
}

/* focus */
.ant-select-item-option.ant-select-item-option-selected:not(.ant-select-item-option-active):not(.ant-select-item-option-disabled) {
  background-color: transparent !important;
  box-shadow: none !important;
  border-radius: var(--list-item-border-radius) !important;
}

.ant-select-dropdown {
  border-radius: var(--list-item-border-radius) !important;
  background-color: var(--color-card-main) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
}

/* ===== 常规输入框 ===== */
.ant-input-outlined {
  background-color: var(--color-background-mute) !important;
  box-shadow: var(--chat-customize-box-shadow4) !important;
  box-sizing: border-box;
  border: 1px solid transparent !important;
}

.ant-input-outlined:hover,
.ant-input-outlined:focus-within {
  border: 1px solid transparent !important;
  outline: none !important;
}

/* 输入框紧贴的按钮 */
.ant-space-compact .ant-btn-variant-outlined {
  background: var(--color-btn-main) !important;
  color: var(--chat-text-user);
  box-shadow: var(--btn-customize-box-shadow);
  border: 1px solid transparent !important;
}

/* 常规按钮 */
.ant-btn-variant-outlined {
  background: var(--color-btn-main) !important;
  color: var(--chat-text-user);
  box-shadow: var(--chat-customize-box-shadow);
  border: transparent !important;
}

/* 常规绿色按钮阴影 */
.ant-btn-variant-solid {
  box-shadow: var(--chat-customize-box-shadow);
}

/* ===== Markdown样式 ===== */
.markdown {
  /* 代码块样式 */
  pre .shiki {
    border: none !important;
    background-color: transparent !important;
    border-radius: 0 !important;
  }

  pre {
    padding: 0 !important;
    border-radius: 12px !important;
    background: none !important;
    box-shadow: none !important;
  }

  pre [class^="CodeBlockWrapper-"] {
    border-radius: 12px !important;
    box-shadow: var(--chat-customize-box-shadow) !important;
    overflow: hidden;
  }

  /* 代码头部样式 */
  pre [class^="CodeHeader-"] {
    border-radius: 12px 12px 0 0 !important;
    background-color: var(--color-card-head) !important;
    border-bottom: none !important;
    margin-bottom: 0 !important;
    justify-content: center;
    color: var(--chat-customize-codeHeader);

    /* 红绿黄指示灯 */
    &::before {
      content: ' ';
      position: absolute;
      top: 10px;
      left: 10px;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #fc625d;
      box-shadow: 20px 0 #35cd4b, 40px 0 #fdbc40;
      z-index: 1;
    }
  }

  /* 代码内容样式 */
  pre [class^="CodeContent-"] {
    background-color: var(--chat-background-assistant) !important;
    border-radius: 0 0 12px 12px !important;
    border-top: none !important;
    margin-top: 0 !important;
    padding-left: 2px;
    padding-right: 2px;
  }
}

/* ===== 其他 ===== */
/* 移除标题背景色 */
.ant-modal-header {
  background-color: transparent !important;
}

/* 选择模型中分组标题背景色 */
.ant-menu-item-group-title {
  background-color: var(--color-background-sec) !important;
}

.ant-modal-body .ant-menu-item.ant-menu-item-selected {
  background-color: var(--color-background-sec) !important;
}

.ant-modal-body div[class^="LeftMenu-"] .ant-menu-item.ant-menu-item-active,
.ant-modal-body div[class^="LeftMenu-"] .ant-menu-item.ant-menu-item-selected {
  background-color: var(--color-background-mute) !important;
  box-shadow: var(--chat-customize-box-shadow) !important;
  border: transparent !important;
}
