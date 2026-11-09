# 提示词配方

按本次任务填入已确认内容，删去无关段落。风格样图管画风，实拍管商品，编辑目标管保留范围。

## 新商品首图

```text
Use case: product-mockup / ads-marketing.
Create one square ecommerce hero in the reference's original 3D pixel construction-brick visual system.
Image1 is STYLE ONLY. Image2 is the actual CURRENT PRODUCT, authoritative for geometry, material, hardware, color and proportions.
Keep the main product photographic; never turn it into bricks or copy another product's parts or claims from Image1.
Main subject/view: [current product and approved viewpoint].
Composition: [dominant placement, clear silhouette, contact/support, secondary decoration].
All scenery, miniature people/animals and decorative symbols are volumetric voxel construction bricks with bevels, seams, raised studs and coherent soft shadows.
Stage: [asymmetric pixel cloud / stepped / crescent / separated islands], many exposed studs, [palette].
Background: predominantly white with an extremely faint [color] glow at [location].
Exact headline: "[approved text]". Single-line centered navy rounded bold Thai lettering and restrained pale-cyan shadow; intact tone marks. Keep series font size/effect and equal blank Logo corners.
No invented product texture, hardware, claims, logos or borrowed character IP.
```

缺失关键实物依据时先找同款材料，不用文字猜零件。

## 多色套图

逐图写清主信息、展示色、整件商品摆位、底座轮廓、角色动作和背景光晕。不只替换上一张的颜色词。精密商品可用稳定视角，通过舞台与角色获得差异。

## 材质精修

```text
Use case: precise-object-edit.
Image1 is the EDIT TARGET. Image2 is the real same-product MATERIAL reference only; ignore its surroundings.
Change ONLY [specified physical surface]. Match the real [finish].
Remove invented [leather grain / emboss / pattern], keeping silhouette, size, opening, true profile groove/collar, axis, pose, neighboring hardware and attachment fixed.
Preserve distinct real materials: in this umbrella case the rigid handle is smooth, while the woven wrist strap retains its fibers and complete loop.
Keep all text, composition, voxel scenery, studs, gradient and shadows. Do not copy desks, devices, people or private surroundings from Image2.
```

光滑由实拍决定，不自动变成镜面镀铬或高光漆；实际接缝和开口不能当成错误纹理抹掉。

## 几何修正

锁定完整实物的可核对视角，冠顶、伞面、巢、杆、柄口作为同一对象。整体旋转或移动，不单独挪杆和柄。局部仍错时换完整视角，并放大连接检查。
直线拟合、曾经改过或模型声称正确都不是验收证据。

## 文字与尺寸

精确引用文案，锁定字形、字号、字影、单行与左右留白。写清测距端点、引线、单位、位于商品哪一侧。只改文字时不重做商品和舞台。

## 调用示例

- 用$pixel-brick-product，按实拍给这个杯子做首图，白底淡桃色、湖蓝积木舞台、左上留Logo，先给审核。
- 用$pixel-brick-product按我提供的商品实拍做九张泰文商品图，忠于实物，每套一张九宫格，暂不覆盖。
- 用$pixel-brick-product，只修握把材质，保留字体、摆位、开口、环形接缝和手绳，给放大前后对比。
