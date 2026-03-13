# Fork依赖文档

本文档记录PiliPro项目中使用的所有fork依赖及其修改原因。

## 概览

| 序号 | 依赖名 | 原始包 | 维护风险 | 迁移建议 |
|------|--------|--------|----------|----------|
| 1 | get | get | **极高** | 迁移到Riverpod |
| 2 | extended_nested_scroll_view | extended_nested_scroll_view | 高 | 评估官方包 |
| 3 | material_design_icons_flutter | material_design_icons_flutter | 中 | 使用官方版本 |
| 4 | auto_orientation | auto_orientation | 高 | 自研实现 |
| 5 | canvas_danmaku | canvas_danmaku | **极高** | 自研实现 |
| 6 | floating | floating | 高 | 评估必要性 |
| 7 | chat_bottom_container | chat_bottom_container | 中 | 评估替代方案 |
| 8 | webdav_client | webdav_client | 中 | 考虑其他包 |
| 9 | flutter_sortable_wrap | flutter_sortable_wrap | 低 | 使用官方版本 |
| 10 | window_manager | window_manager | 中 | **桌面端已废弃，可移除** |
| 11 | file_picker | file_picker | 中 | 使用官方版本 |
| 12 | super_sliver_list | super_sliver_list | 高 | 使用官方版本 |

---

## 详细说明

### 1. get (状态管理)

**Fork URL**: https://github.com/bggRGjQaUbCoE/getx.git  
**Ref**: version_4.7.2  
**原始包**: https://pub.dev/packages/get

**修改原因**:
- 定制化状态管理行为
- 可能修复了特定bug或添加了特定功能

**风险评估**: 🔴 **极高**
- 状态管理是应用核心
- GetX 4.x版本已停止维护
- Fork版本可能包含未文档化的修改

**迁移路径**:
1. 短期：记录当前使用的GetX功能
2. 中期：评估Riverpod或BLoC
3. 长期：逐步迁移（可先迁移非核心页面）

**检查命令**:
```bash
# 查找项目中使用的GetX功能
grep -r "Get\.\|GetxController\|Obx\|GetBuilder\|Rx" lib/ --include="*.dart" | wc -l
```

---

### 2. extended_nested_scroll_view

**Fork URL**: https://github.com/bggRGjQaUbCoE/extended_nested_scroll_view.git  
**Ref**: mod  
**原始包**: https://pub.dev/packages/extended_nested_scroll_view

**修改原因**:
- 解决Sliver滑动不同步问题
- 定制化滚动行为

**风险评估**: 🟡 高
- 影响UI交互
- 需测试滚动行为是否正常

**迁移路径**:
- 检查官方版本是否已修复相关问题
- 如官方版本可用，优先使用官方

---

### 3. material_design_icons_flutter

**Fork URL**: https://github.com/bggRGjQaUbCoE/material_design_icons_flutter.git  
**Ref**: const  
**原始包**: https://pub.dev/packages/material_design_icons_flutter

**修改原因**:
- 添加const支持以提高性能

**风险评估**: 🟢 中
- 只是图标包
- 修改简单，风险可控

**迁移路径**:
- 检查官方版本是否已支持const
- 如支持，可直接替换

---

### 4. auto_orientation

**Fork URL**: https://github.com/bggRGjQaUbCoE/auto_orientation.git  
**Ref**: master  
**原始包**: https://pub.dev/packages/auto_orientation

**修改原因**:
- 定制化屏幕旋转行为
- 可能修复了特定场景下的问题

**风险评估**: 🟡 高
- 影响播放器体验
- 旋转逻辑复杂，容易出错

**迁移路径**:
- 考虑自研简单的屏幕旋转控制
- 或寻找其他维护良好的包

---

### 5. canvas_danmaku (弹幕渲染)

**Fork URL**: https://github.com/bggRGjQaUbCoE/canvas_danmaku.git  
**Ref**: main  
**原始包**: https://pub.dev/packages/canvas_danmaku

**修改原因**:
- 定制化弹幕渲染行为
- 性能优化
- 特定功能支持

**风险评估**: 🔴 **极高**
- 弹幕是核心功能
- 渲染性能敏感
- 代码复杂度高

**迁移路径**:
1. 短期：记录当前使用的功能和API
2. 中期：自研基于CustomPainter的弹幕系统（约100-200行代码）
3. 长期：完全替换

**自研建议**:
- 使用CustomPainter + AnimationController
- 参考现有fork的实现，提取核心逻辑
- 保持API兼容以便平滑迁移

---

### 6. floating (画中画)

**Fork URL**: https://github.com/bggRGjQaUbCoE/floating.git  
**Ref**: version-3  
**原始包**: https://pub.dev/packages/floating

**修改原因**:
- 定制化画中画行为
- 修复特定平台问题

**风险评估**: 🟡 高
- 画中画是高级功能
- 平台差异大，测试复杂

**迁移路径**:
- 评估是否必须使用画中画
- 考虑使用原生实现替代

---

### 7. chat_bottom_container

**Fork URL**: https://github.com/bggRGjQaUbCoE/flutter_chat_packages.git  
**Path**: packages/chat_bottom_container  
**Ref**: main  
**原始包**: https://pub.dev/packages/chat_bottom_container

**修改原因**:
- 定制化聊天输入框行为
- 可能修复了键盘弹出问题

**风险评估**: 🟢 中
- 影响评论输入体验
- 但修改范围有限

**迁移路径**:
- 评估官方版本
- 或使用更简单的自定义实现

---

### 8. webdav_client

**Fork URL**: https://github.com/wgh136/webdav_client.git  
**Ref**: main  
**原始包**: https://pub.dev/packages/webdav_client

**修改原因**:
- 可能添加了特定功能或修复了bug

**风险评估**: 🟢 中
- WebDAV是可选功能
- 影响范围有限

**迁移路径**:
- 检查官方版本是否满足需求
- 或使用dio直接实现WebDAV协议

---

### 9. flutter_sortable_wrap

**Fork URL**: https://github.com/bggRGjQaUbCoE/flutter_sortable_wrap.git  
**Ref**: master  
**原始包**: https://pub.dev/packages/flutter_sortable_wrap

**修改原因**:
- 定制化拖拽排序行为

**风险评估**: 🟢 低
- 使用场景有限（设置页面拖拽排序）
- 容易替换

**迁移路径**:
- 检查官方版本
- 如不可用，可使用ReorderableListView替代

---

### 10. window_manager

**Fork URL**: https://github.com/bggRGjQaUbCoE/window_manager.git  
**Path**: packages/window_manager  
**Ref**: main  
**原始包**: https://pub.dev/packages/window_manager

**修改原因**:
- 桌面端窗口管理定制

**风险评估**: 🟢 **可移除**
- ⚠️ **桌面端支持已停止**
- 此依赖在Android/iOS上无用

**迁移路径**:
- ✅ **立即移除**
- 从pubspec.yaml中删除

---

### 11. file_picker

**Fork URL**: https://github.com/bggRGjQaUbCoE/flutter_file_picker.git  
**Ref**: v10.3.10  
**原始包**: https://pub.dev/packages/file_picker

**修改原因**:
- 定制化文件选择行为
- 可能修复了特定平台问题

**风险评估**: 🟢 中
- 使用频率不高
- 官方版本通常足够

**迁移路径**:
- 评估官方版本是否满足需求
- 直接使用官方版本

---

### 12. super_sliver_list

**Fork URL**: https://github.com/bggRGjQaUbCoE/super_sliver_list.git  
**Ref**: mod  
**原始包**: https://pub.dev/packages/super_sliver_list

**修改原因**:
- 定制化列表性能优化
- 可能添加了特定功能

**风险评估**: 🟡 高
- 影响列表性能
- 但官方版本可能已有改进

**迁移路径**:
- 测试官方版本性能
- 如官方版本可用，直接替换

---

## 维护检查清单

### 每月检查
- [ ] 检查fork仓库是否有更新
- [ ] 检查原始包是否有重要更新
- [ ] 检查是否有安全漏洞

### 升级流程
1. 在隔离分支测试新版本
2. 对比diff查看修改内容
3. 运行完整测试（功能测试、性能测试）
4. 合并到主分支

### 紧急情况处理
如果发现fork依赖有严重bug或安全漏洞：
1. 评估影响范围
2. 寻找替代方案（官方包或自研）
3. 临时patch或回滚
4. 制定迁移计划

---

## 建议优先级

### 🔴 立即处理（本月）
1. **window_manager** - 桌面端已废弃，立即移除
2. **get** - 开始规划迁移方案

### 🟡 短期处理（3个月内）
3. **canvas_danmaku** - 开始自研替代方案
4. **floating** - 评估是否必要
5. **file_picker** - 测试官方版本

### 🟢 中期处理（6个月内）
6. **material_design_icons_flutter** - 检查官方版本
7. **flutter_sortable_wrap** - 寻找替代
8. **webdav_client** - 评估官方版本

### 🔵 长期规划（12个月内）
9. **extended_nested_scroll_view** - 随GetX迁移一起处理
10. **auto_orientation** - 自研或寻找替代
11. **chat_bottom_container** - 随UI框架升级处理
12. **super_sliver_list** - 性能测试后决定

---

## 相关文件

- `pubspec.yaml` - 依赖声明
- `lib/scripts/` - 构建脚本
- `.github/workflows/` - CI/CD配置

---

*文档最后更新: 2026-03-13*  
*维护者: 待填写*  
*审核周期: 每季度*
