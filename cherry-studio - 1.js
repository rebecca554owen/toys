/* CSS变量定义 */
.TagsContainer-erHQJu:nth-child(1) { --group-color: 59, 130, 246; }
.TagsContainer-erHQJu:nth-child(2) { --group-color: 34, 197, 94; }
.TagsContainer-erHQJu:nth-child(3) { --group-color: 168, 85, 247; }
.TagsContainer-erHQJu:nth-child(4) { --group-color: 249, 115, 22; }
.TagsContainer-erHQJu:nth-child(5) { --group-color: 239, 68, 68; }
.TagsContainer-erHQJu:nth-child(6) { --group-color: 6, 182, 212; }
.TagsContainer-erHQJu:nth-child(7) { --group-color: 245, 158, 11; }
.TagsContainer-erHQJu:nth-child(8) { --group-color: 156, 163, 175; }
.TagsContainer-erHQJu:nth-child(9) { --group-color: 219, 39, 119; }
.TagsContainer-erHQJu:nth-child(10) { --group-color: 99, 102, 241; }

/* 分组容器基础样式 */
.TagsContainer-erHQJu {
    margin: 12px 8px;
    padding: 12px 8px;
    border-radius: 12px;
    background: rgba(var(--group-color, 156, 163, 175), 0.06);
    border: 1px solid rgba(var(--group-color, 156, 163, 175), 0.12);
    overflow: hidden;
}

.TagsContainer-erHQJu:has(.GroupTitle-bZsCjw) {
    padding: 0;
}

/* 分组标题 */
.GroupTitle-bZsCjw {
    margin: 0;
    padding: 14px 16px;
    background: rgba(var(--group-color, 156, 163, 175), 0.12);
    border: none;
    border-radius: 12px 12px 0 0;
    border-bottom: 1px solid rgba(var(--group-color, 156, 163, 175), 0.08);
    cursor: pointer;
    transition: all 0.2s ease;
}

.GroupTitle-bZsCjw:hover {
    background: rgba(var(--group-color, 156, 163, 175), 0.16);
}

.GroupTitleName-ifOZPj {
    font-weight: 600;
    font-size: 14px;
    color: rgba(var(--group-color, 156, 163, 175), 0.9);
    display: flex;
    align-items: center;
    margin: 0;
    letter-spacing: 0.025em;
}

.GroupTitleName-ifOZPj .anticon {
    margin-right: 8px;
    color: rgba(var(--group-color, 156, 163, 175), 0.7);
    font-size: 12px;
    transition: all 0.2s ease;
}

.GroupTitleDivider-hDobAZ {
    display: none;
}

.TagsContainer-erHQJu:has(.GroupTitle-bZsCjw) > div:not(.GroupTitle-bZsCjw) {
    padding: 0 12px;
}

.TagsContainer-erHQJu:has(.GroupTitle-bZsCjw) .Container-lnWGMS:last-of-type,
.TagsContainer-erHQJu:has(.GroupTitle-bZsCjw) .AssistantAddItem-cnwcTr {
    margin-bottom: 12px;
}

/* 助手容器 */
.Container-cFFyqi {
    display: flex;
    align-items: center;
    width: 100%;
    border-radius: 8px;
    transition: all 0.25s ease;
    margin: 2px 0;
    background: transparent;
}

.AssistantNameRow-eRVxCS {
    padding: 10px 12px;
    background: transparent !important;
    border: none;
    display: flex;
    align-items: center;
    flex: 1;
    min-width: 0;
    border-radius: inherit;
    transition: all 0.25s ease;
}

.Container-gOOWxz {
    display: flex;
    align-items: center;
    flex-shrink: 0;
}

.AssistantName-cHMAyM {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: #e5e7eb;
    font-size: 13px;
    font-weight: 400;
    transition: all 0.25s ease;
    flex: 1;
    min-width: 0;
    margin-left: 8px;
}

/* 修复双重圆形的关键：去除MenuButton背景 */
.MenuButton-kywHgl {
    display: flex;
    align-items: center;
    flex-shrink: 0;
    margin-left: 8px;
    background: none !important;
    border: none !important;
    box-shadow: none !important;
    padding: 0 !important;
}

.TopicCount-IXqyx {
    background: rgba(255, 255, 255, 0.08);
    color: #9ca3af;
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 10px;
    padding: 2px 6px;
    font-size: 11px;
    font-weight: 500;
    min-width: 16px;
    text-align: center;
    line-height: 1.2;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    transition: all 0.25s ease;
    box-shadow: none;
}

/* hover状态 */
.Container-cFFyqi:hover {
    background: rgba(var(--group-color, 156, 163, 175), 0.08) !important;
}

.Container-cFFyqi:hover .TopicCount-IXqyx {
    background: rgba(var(--group-color, 156, 163, 175), 0.12);
    border-color: rgba(var(--group-color, 156, 163, 175), 0.2);
    color: rgba(var(--group-color, 156, 163, 175), 0.85);
    transform: scale(1.02);
}

/* 激活状态 */
.Container-cFFyqi.active {
    background: rgba(var(--group-color, 156, 163, 175), 0.1) !important;
    border: 1px solid rgba(var(--group-color, 156, 163, 175), 0.2);
    box-shadow: 0 1px 2px rgba(var(--group-color, 156, 163, 175), 0.08);
}

.Container-cFFyqi.active .AssistantNameRow-eRVxCS {
    font-weight: 500;
}

.Container-cFFyqi.active .AssistantName-cHMAyM {
    color: rgba(var(--group-color, 156, 163, 175), 0.95) !important;
    font-weight: 500;
}

.Container-cFFyqi.active .TopicCount-IXqyx {
    background: rgba(var(--group-color, 156, 163, 175), 0.9);
    color: #ffffff !important;
    border-color: rgba(var(--group-color, 156, 163, 175), 0.9);
    font-weight: 600;
    transform: scale(1.02);
}

.Container-cFFyqi.active:hover {
    background: rgba(var(--group-color, 156, 163, 175), 0.14) !important;
    box-shadow: 0 2px 3px rgba(var(--group-color, 156, 163, 175), 0.12);
    transform: translateX(1px);
}

.Container-cFFyqi.active:hover .TopicCount-IXqyx {
    background: rgba(var(--group-color, 156, 163, 175), 1);
    color: #ffffff !important;
    border-color: rgba(var(--group-color, 156, 163, 175), 1);
    transform: scale(1.05);
}

/* 浅色模式 */
@media (prefers-color-scheme: light) {
    .AssistantName-cHMAyM {
        color: #374151;
    }
    
    .GroupTitleName-ifOZPj {
        color: rgba(var(--group-color, 156, 163, 175), 0.85);
    }
    
    .GroupTitleName-ifOZPj .anticon {
        color: rgba(var(--group-color, 156, 163, 175), 0.65);
    }
    
    .Container-cFFyqi.active .AssistantName-cHMAyM {
        color: rgba(var(--group-color, 156, 163, 175), 0.9) !important;
    }
    
    .Container-cFFyqi:hover {
        background: rgba(var(--group-color, 156, 163, 175), 0.06) !important;
    }
    
    .Container-cFFyqi.active {
        background: rgba(var(--group-color, 156, 163, 175), 0.08) !important;
        border-color: rgba(var(--group-color, 156, 163, 175), 0.25);
        box-shadow: 0 1px 2px rgba(var(--group-color, 156, 163, 175), 0.06);
    }
    
    .Container-cFFyqi.active:hover {
        background: rgba(var(--group-color, 156, 163, 175), 0.12) !important;
        box-shadow: 0 2px 3px rgba(var(--group-color, 156, 163, 175), 0.1);
    }
    
    .TopicCount-IXqyx {
        background: rgba(0, 0, 0, 0.05);
        color: #6b7280;
        border-color: rgba(0, 0, 0, 0.08);
    }
    
    .Container-cFFyqi:hover .TopicCount-IXqyx {
        background: rgba(var(--group-color, 156, 163, 175), 0.1);
        color: rgba(var(--group-color, 156, 163, 175), 0.8);
        border-color: rgba(var(--group-color, 156, 163, 175), 0.15);
    }
}

/* 深色模式 */
@media (prefers-color-scheme: dark) {
    .TagsContainer-erHQJu {
        background: rgba(var(--group-color, 156, 163, 175), 0.08);
        border-color: rgba(var(--group-color, 156, 163, 175), 0.15);
    }
    
    .GroupTitle-bZsCjw {
        background: rgba(var(--group-color, 156, 163, 175), 0.15);
        border-bottom-color: rgba(var(--group-color, 156, 163, 175), 0.1);
    }
    
    .GroupTitle-bZsCjw:hover {
        background: rgba(var(--group-color, 156, 163, 175), 0.2);
    }
    
    .GroupTitleName-ifOZPj {
        color: rgba(var(--group-color, 156, 163, 175), 0.95);
    }
    
    .GroupTitleName-ifOZPj .anticon {
        color: rgba(var(--group-color, 156, 163, 175), 0.8);
    }
    
    .Container-cFFyqi:hover {
        background: rgba(var(--group-color, 156, 163, 175), 0.1) !important;
    }
    
    .Container-cFFyqi.active {
        background: rgba(var(--group-color, 156, 163, 175), 0.12) !important;
        border-color: rgba(var(--group-color, 156, 163, 175), 0.3);
        box-shadow: 0 1px 2px rgba(var(--group-color, 156, 163, 175), 0.1);
    }
    
    .Container-cFFyqi.active:hover {
        background: rgba(var(--group-color, 156, 163, 175), 0.16) !important;
        box-shadow: 0 2px 3px rgba(var(--group-color, 156, 163, 175), 0.15);
    }
}

/* 表情符号背景 */
.EmojiBackground-fPdsEN {
    border-radius: 6px;
    margin-right: 8px;
    flex-shrink: 0;
    width: 20px;
    height: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.25s ease;
}

/* 添加助手按钮 */
.AssistantAddItem-cnwcTr {
    margin: 8px 0 0 0;
    padding: 12px;
    border: 2px dashed rgba(var(--group-color, 156, 163, 175), 0.3);
    border-radius: 8px;
    background: rgba(var(--group-color, 156, 163, 175), 0.02);
    transition: all 0.25s ease;
    cursor: pointer;
    width: 100%;
}

.AssistantAddItem-cnwcTr:hover {
    border-color: rgba(var(--group-color, 156, 163, 175), 0.5);
    background: rgba(var(--group-color, 156, 163, 175), 0.08);
    transform: translateY(-1px);
    box-shadow: 0 2px 8px rgba(var(--group-color, 156, 163, 175), 0.15);
}

.AssistantAddItem-cnwcTr .AssistantName-hllWJP {
    color: rgba(var(--group-color, 156, 163, 175), 0.8);
    font-size: 13px;
    display: flex;
    align-items: center;
    font-weight: 500;
}

.AssistantAddItem-cnwcTr .anticon-plus {
    margin-right: 8px;
    font-size: 12px;
    color: rgba(var(--group-color, 156, 163, 175), 0.9);
}

@media (prefers-color-scheme: dark) {
    .AssistantAddItem-cnwcTr {
        border-color: rgba(var(--group-color, 156, 163, 175), 0.25);
        background: rgba(var(--group-color, 156, 163, 175), 0.03);
    }
    
    .AssistantAddItem-cnwcTr:hover {
        border-color: rgba(var(--group-color, 156, 163, 175), 0.4);
        background: rgba(var(--group-color, 156, 163, 175), 0.1);
    }
    
    .AssistantAddItem-cnwcTr .AssistantName-hllWJP {
        color: rgba(var(--group-color, 156, 163, 175), 0.9);
    }
    
    .AssistantAddItem-cnwcTr .anticon-plus {
        color: rgba(var(--group-color, 156, 163, 175), 0.95);
    }
}

/* 优雅流彩动画 */
@keyframes elegantFlow {
    0% {
        background-position: 0 50%;
    }
    50% {
        background-position: 100% 50%;
    }
    100% {
        background-position: 0 50%;
    }
}

/* 轻柔发光 */
@keyframes softGlow {
    0%, 100% {
        box-shadow: 0 0 10px rgba(255, 106, 1, 0.1);
    }
    50% {
        box-shadow: 0 0 15px rgba(138, 43, 226, 0.15);
    }
}

/* 输入框优雅流彩效果 */
#inputbar {
    position: relative;
}

#inputbar::before {
    content: "";
    position: absolute;
    inset: -2px;
    border-radius: inherit;
    padding: 2px;
    background: linear-gradient(
        90deg,
        #ff6a01,    /* 爱马仕橙 */
        #f8c91c,    /* 那不勒斯黄 */
        #8a2be2,    /* 紫罗兰色 */
        #00bfff,    /* 天蓝色 */
        #ff6a01     /* 回到橙色 */
    );
    background-size: 300% 300%;
    mask:
        linear-gradient(#000 0 0) content-box,
        linear-gradient(#000 0 0);
    -webkit-mask-composite: destination-out;
    mask-composite: exclude;
    animation: elegantFlow 6s ease-in-out infinite;
    opacity: 0;
    transition: opacity 0.6s ease;
    pointer-events: none;
    z-index: -1;
}

#inputbar:focus-within::before {
    opacity: 1;
}

#inputbar:focus-within {
    animation: softGlow 3s ease-in-out infinite;
}

/* Markdown 内容样式 */
/* Light模式样式 */
body[theme-mode="light"] .markdown h1 { font-size: 2em; color: #FF5252; border: none; padding-bottom: 0; }
body[theme-mode="light"] .markdown h2 { font-size: 1.75em; color: #FFA040; border: none; padding-bottom: 0; }
body[theme-mode="light"] .markdown h3 { font-size: 1.5em; color: #FDD800; border: none; padding-bottom: 0; }
body[theme-mode="light"] .markdown h4 { font-size: 1.25em; color: #4CAF50; border: none; padding-bottom: 0; }
body[theme-mode="light"] .markdown h5 { font-size: 1.1em; color: #03A9F4; border: none; padding-bottom: 0; }
body[theme-mode="light"] .markdown h6 { font-size: 1em; color: #673AB7; border: none; padding-bottom: 0; }
body[theme-mode="light"] .markdown strong { color: #C08080; }
body[theme-mode="light"] .markdown em { color: #7986CB; font-style: italic; }
body[theme-mode="light"] .markdown hr { border: none; height: 1px; background: linear-gradient(90deg, transparent, #E5FFFF, transparent); }
body[theme-mode="light"] .markdown a { color: #42A5F5; }
body[theme-mode="light"] .markdown a:hover { color: #1976D2; text-decoration: none; }

/* Dark模式样式 */
body[theme-mode="dark"] .markdown h1 { font-size: 2em; color: #FFADAD; border: none; padding-bottom: 0; }
body[theme-mode="dark"] .markdown h2 { font-size: 1.75em; color: #FFD6A5; border: none; padding-bottom: 0; }
body[theme-mode="dark"] .markdown h3 { font-size: 1.5em; color: #FDFFB6; border: none; padding-bottom: 0; }
body[theme-mode="dark"] .markdown h4 { font-size: 1.25em; color: #CAFFBF; border: none; padding-bottom: 0; }
body[theme-mode="dark"] .markdown h5 { font-size: 1.1em; color: #9BF6FF; border: none; padding-bottom: 0; }
body[theme-mode="dark"] .markdown h6 { font-size: 1em; color: #A0C4FF; border: none; padding-bottom: 0; }
body[theme-mode="dark"] .markdown strong { color: #FFFF99; }
body[theme-mode="dark"] .markdown em { color: #C7CEEA; font-style: italic; }
body[theme-mode="dark"] .markdown hr { border: none; height: 1px; background: linear-gradient(90deg, transparent, #E5FFFF, transparent); }
body[theme-mode="dark"] .markdown a { color: #A2FDB5; }
body[theme-mode="dark"] .markdown a:hover { color: #81C784; text-decoration: none; }