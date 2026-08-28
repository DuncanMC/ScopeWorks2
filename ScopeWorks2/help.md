**ScopeWorks help**

Introduction:

ScopeWorks is a program for Macs and iPads that lets you create stunning kaleidoscopes using still images or feeds from an attached video camera.

ScopeWorks works best on iPads with external keyboards.

It is a document based application. Once you launch it, you will need to create a new document and provide a source image. You will then work with ScopeWorks document windows.

The first time you create a new document after installing the program, you will be prompted to create or select existing folders for your ScopeWorks documents, Kaleidoscope Source images, and saved images or videos. We suggest you create these folders on your iCloud Drive so you can share them between copies of ScopeWorks running on different Macs and iPads that have access to the same iCloud Drive. 

ScopeWorks will install a few sample images into the ScopeWorks Source Images directory, and a few sample documents into the ScopeWorks Documents directory.

Select "New" from the file menu to create a new ScopeWorks document. On MacOS you can have multiple ScopeWorks document windows open at the same time. On iOS, you can only open one.

ScopeWorks creates polygon based kaleidoscopes and square-based kaleidoscopes. Both types take a triangular “slice” of your source image/video and copy/flip that triangular slice in different ways to create a wide variety of kaleidoscopes. The controls in a document window and in the View menu let you change the way the kaleidoscope looks and animates.

**The ScopeWorks document window**:

The document window displays your source image in the top left, and your kaleidoscope on the top right. The bottom of the window displays various controls that let you change the settings of your kaleidoscope. There are also a number of settings in the View menu (Which is displayed as an eyeball at the top of the screen on iOS.)

**Image source view**:  
Once you select an image source, the image source view on the top left of the document window will display that image, along with an outline of the triangular section of the source image that is currently being used to create your kaleidoscope. There will also be a small circle showing the center of rotation used to animate the source triangle and an arrow showing the direction of rotation, clockwise or counterclockwise. 

If you drag the rotation center you can move it around on the source image. If you drag inside the source triangle, you can move the triangle around on the source image. If you drag outside the source triangle, you can manually rotate it around the rotation center point. If you option-drag (on macOS) outside the source triangle, you can rotate it around the center of the triangle. On iPad use two-finger rotation to rotate the source triangle around its center point.

If you drag one of the corners of the triangle you can resize the source triangle.

If you tap in the image source view (or press tab on an external keyboard to select it on iOS) it gains focus and will show a light blue outline. When the image source view is in focus, pressing one of the arrow keys on your keyboard (including an external keyboard on an iPad) will shift the source triangle 1 pixel in that direction. If you hold down the shift key and press an arrow key, the source triangle will be shifted by 10 pixels.

**Kaleidoscope view**  
The kaleidoscope view in the top right of the document window shows a small view of your kaleidoscope. The "Show outlines" view menu toggle shows the outlines of the triangular sections of your source image that are tiled together to create your kaleidoscope.  
The "Show crop rectangle" view menu toggle shows the section of your kaleidoscope that will be saved if you tap (or two-finger tap on iOS) on your kaleidoscope view. It also indicates the section of your kaleidoscope that will be saved if you choose "Save image as" from the file menu and don't change the aspect ratio in the save dialog, and the portion of your kaleidoscope that will be used to create a video with the file menu “Record Video” command. The shape of this crop rectangle is controlled by the aspect ratio you select in the Settings screen.

**Controls**: 

**Image source button:** 

Once you've created a new document, tap the "Image Source" button to select an image source for your kaleidoscope. You can either select a still image from disk or your photo library, or choose an available video camera. (On iOS, you can select the front or rear-facing camera, and on Mac, you can select the built-in camera on a MacBook or an attached webcam.   
For all the current kaleidoscope types, ScopeWorks takes a triangular section of your source image and "tessellates" it (laying the triangular sections next to each other) to create a kaleidoscope. Future versions of the program may tessellate more complex shapes than triangles.  
If you choose a still image as your image source, and that image is a PNG or TIFF image with transparency, ScopeWorks will allow the selected background color to show through the transparent parts of your source image, and if you choose "draw with reflection" from the view menu, your source image will be drawn twice: Once normally, and then again flipped to a mirror image of itself. Kaleidoscopes created from partly transparent images with "Draw with Reflection" create interesting [Moiré patterns](https://en.wikipedia.org/wiki/Moir%C3%A9_pattern). Open the sample ScopeWorks document “example” and turn on animation to see this effect.

**Kaleidoscope type**: (Default setting: Polygon grid)

ScopeWorks currently supports polygon based "fan style" kaleidoscopes built from "pie slice" shaped triangular sections of your source image, or square-based kaleidoscopes that are built from triangles shaped like a square cut in half diagonally. (Triangles with an angle of 45°, 45°, and 90° and two equal sides.)  
**Kaleidoscope types:**   
**Pologon**: A "polygon" Kaleidoscope is a single polygon centered in a square. It defaults to 6 sides, which creates a hexagon shape. By default alternate triangles are flipped, causing the edges of each triangular section to match with the mirrored adjacent image and creating an image without “seams”.  
**Polygon Grid**: A polygon grid is, as the name suggests, a grid of polygons packed together. If you select the default 6-sided polygons, they pack together with no gaps. A 6-sided polygon grid creates kaleidoscopes like those from traditional 3 mirror kaleidoscopes where the mirrors are set at 60° angles.   
**8-way square**:   
ScopeWorks takes a square and draws diagonal lines from the corners, then draws lines down the center horizontally and vertically. This creates 8 isosceles right triangles. (Triangles with an angle of 45°, 45°, and 90° and two equal sides.) A triangular slice of your source image is drawn in each of these 8 triangles.   
**8-way tiles**:  
Four 8-way squares are stacked two-by-two, creating a repeating pattern of squares.

**Polygon Sides**:  (Only used for Polygon and Polygon grid kaleidoscope types. Default setting: 6\)  
Not used for 8-way square and 8-way tiles kaleidoscope types.  
For the "Polygon" and "Polygon grid" kaleidoscope types, this value determines how many "pie slices" make up a polygon in your kaleidoscope. The default is 6 sides, which creates a traditional kaleidoscope. Even numbers will create polygons that tessellate seamlessly when "flip alternates" is checked in the view menu (The default.) Odd values will always create at least 1 visible "seam" where the edges of the image triangles don't line up. 

**Split polygon triangles checkbox/switch**: (Only used for Polygon and Polygon grid kaleidoscope types)  
This checkbox lets you split each triangle in polygon-based kaleidoscope types into 2 symmetrical triangles. This is especially useful for 6-sided polygon grid kaleidoscopes, since it creates hexagons from pairs of split triangles, and those hexagons tile (tesselate) perfectly without any gaps or overlap.

**Fullscreen Display popup**:  
This popup lets you select the screen that will be used if you choose "Show full-screen Kaleidoscope" from the view menu. If you don't have multiple displays (external monitors on macOS or available AirPlay screens on iOS) the only option will be your main display.

**Rotation speed slider**:  
This controls how fast ScopeWorks rotates the source triangle around the rotation center in the source image when animation is selected in the View menu. Values range from \-15 (max clockwise rotation) to 15 (max rotation counter-clockwise  
**Zoom slider**:  
This slider lets you zoom in to a portion of your kaleidoscope, showing more detail of the center section. Values range from 1 (no zoom) to 2.5 (2.5x magnification)

**Radius slider**: (Only used for Polygon grid kaleidoscope type)  
This controls the size (radius) of each polygon in the grid. With the default value of 1, the polygons are about each other. At smaller radius values, ScopeWorks leaves a gap between polygons Values range from 1.0 (full sized polygons with no gaps) to 0.5 (half-sized polygons with large gaps between them.

**The View menu**:

The view menu (in the menu bar on Mac, and in the "eyeball" toolbar on iOS) provides a large number of settings that let you change the look of your Scopeworks window. These items are only enabled when a ScopeWorks document window is active. (Note that all the items in the view menu have keyboard shortcuts, which work even if a full-screen display is covering the document window.)

**Show Controls toggle**: (defaults to on)  
Use this option to show or hide the controls in the front ScopeWorks window. When you hide controls the source image and kaleidoscope views grow taller.

**Show source image:**  
Use this option to show or hide the source image view in the front ScopeWorks window. When you hide the source image the kaleidoscope views grow wider. If you hide both the controls and the source image for a document the kaleidoscope view fills the whole document window.

**Show outlines:**  
When checked, ScopeWorks draws lines in the kaleidoscope view showing the boundaries between the triangles that make up your kaleidoscope. These outlines will be saved in snapshots and in saved images.

**Flip Alternates:** (Defaults to on.)  
When checked, each alternate triangle in the kaleidoscope is drawn flipped into a mirror image of its neighbors. This causes the "seams" of the triangular image sections to line up, creating a seamless image.

**Draw With reflection:**  
When checked, each triangle in your kaleidoscope is drawn twice: Once normally, and once flipped to its mirror image. This only makes a visible difference if your source image is partly transparent. In that case, the mirror image shows through the transparent areas of the source image, creating interesting [Moiré patterns](https://en.wikipedia.org/wiki/Moir%C3%A9_pattern).

**Animate**  
When checked, ScopeWorks rotates the source triangle around the center of rotation. The rotation speed slider controls how fast it animates.

**Reverse Animation**  
This menu item reverses the direction of the source triangle animation.

**Advance animation one frame**  
This menu option advances the animation by a single frame (the amount of change that would take place in 1/120th of a second.) It lets you fine-tune the look of your kaleidoscope if you are trying to create a specific effect. (Useful when animation is paused, in combination with the Reverse Animation menu option)

**Show Crop Rectangle**  
When checked, ScopeWorks shows an outline of the part of the kaleidoscope view that will be saved if you trigger a snapshot or use the "Save image as" file menu command with the currently selected aspect ratio.

**Show Full-screen Kaleidoscope**   
When checked, ScopeWorks fills the display specified with the "Fullscreen Display" popup with the kaleidoscope view of the front ScopeWorks window. On iOS, you can two-finger tap on the full screen display to take a snapshot. All the keyboard shortcuts are available when the full screen display is active, even if it covers the document window. Note that on Macs with multiple monitors, each monitor can show a different full-screen kaleidoscope at the same time.

**Select next full-screen display**  
This menu item cycles the Fullscreen display popup between the available displays on your system. If the fullscreen display is active it will move it to the next display. It has no effect if you only have one available display.

**The File Menu**

**New**:  
Creates a new, blank kaleidoscope. You need to click the “image source” button and pick an image source before your kaleidoscope will show any contents.

**Open**:  
Displays a dialog/picker that lets you open an existing ScopeWorks document. On macOS you can open a document from anywhere you have read access to. iOS limits you to a small number of folders. In general you should load and save ScopeWorks documents to the “ScopeWorks Documents” folder you set up when you first installed the program.

**Open Recent**:  
This is a standard system item that lets you quickly open documents you’ve worked with recently.

**Save Image as**:  
Shows a save panel/picker and saves an image of the current kaleidoscope to the path you select. It defaults to using the file format and aspect ratio specified in the settings window, and image width and height values based on the selected aspect ratio. You can change any of those values in the save panel/picker.

**Record video**:  
Displays a control that lets you start recording the current kaleidoscope to a movie file. It uses the aspect ratio specified in the settings window.

**Create Kaleidoscope from Image Data**:  
This menu item prompts you to select a ScopeWorks image file. It attempts to create a ScopeWorks document with settings embedded in the image metadata that were used to create the image. It only works for ScopeWorks image files saved with the “Include kaleidoscope info in saved images” settings checkbox checked.

All the other items in the File menu are standard system menu items.

	

**The settings screen**:

To display the settings screen, tap the settings gear in the lower right of the document window on iOS, or select Settings from the ScopeWorks menu.

**Snapshot filetype popup**:  
This popup controls the filetype used for saving snapshots, and the default filetype used in the "Save Image As" file menu command.

**Include kaleidoscope info in saved images checkbox**:  
When checked, ScopeWorks includes metadata in saved PNG, JPEG, and TIFF files that let you recreate the kaleidoscope document with the same settings that were used to create the saved image. (It won’t be able to recreate an image or snapshot created from a video feed.)

**Embed image thumbnails in documents checkbox**:  
When selected, ScopeWorks includes a thumbnail image of your kaleidoscope into ScopeWorks documents. On macOS, it also adds the thumbnail to the finder info for your document so the document shows its image thumbnail in the finder. On iOS ScopeWorks provides a “Thumbnail Extension” that allows the Files application to show these image thumbnails.

**Image/Video aspect ratio** picker:  
This popup controls the aspect ratio and default height and width values used to save images and videos. Note that snapshots of the full-screen kaleidoscope view ignore this setting and always take a snapshot of the whole fullscreen display. If you select “Show Crop Rectangle” in the view menu ScopeWorks will draw a rectangle in the kaleidoscope view indicating the section of your kaleidoscope that will used for saving snapshots, images, and videos (other than full-screen snapshots, as mentioned.) ScopeWorks shows the width and height of your selected aspect ratio (reduced by removing common factors, e.g. 1920:1080 will be reduced to 16:9) It will show the multiplier used to calculate the default pixel dimensions for saving, and also show those pixel dimensions.

**Add custom aspect ratio** button:  
Clicking this button displays the custom aspect ratio editor. 

**Delete custom aspect ratio** button:  
If you add a custom aspect ratio and select it, ScopeWorks will display this button. Tapping it deletes your custom aspect ratio, and selects a different aspect ratio from the list of remaining aspect ratios. 

**Folders**:  
This section of the settings view shows the Folders ScopeWorks uses to load source images and ScopeWorks documents,and for saving snapshots. The "Snapshots" folder is also the default directory used for saving images and videos.   
   
**Re-configure Folders button**:  
Tap/click this button to change the folders ScopeWorks uses for loading and saving documents, images, and videos.

**The Custom Aspect Ratio editor**:

This editor is displayed when you click “Add custom aspect ratio” from the settings screen. It is used to create your own custom aspect ratios for saving snapshots and images. (Note that snapshots taken from a fullscreen kaleidoscope view ignore the selected aspect ratio and always save a full screen image of the kaleidoscope. If you tap (or two-finger tap in the iPad version) on the kaleidoscope, ScopeWorks will automatically save a snapshot of your kaleidoscope using the desired aspect ratio and computed pixel dimensions. If you select “Save Image as” or “Record Video” from the file menu, ScopeWorks uses your current aspect ratio to calculate the default pixel dimensions for creating your file, but you can change those defaults.

To create a custom aspect ratio, give it a unique name, and then either enter an aspect ratio width, height, and multiplier and then click “Calculate Pixels”, or enter pixel width and height and then click “Calculate Aspect”. If you enter an aspect width, height and multiplier, the “calculate pixels” button multiplies the aspect width by the multiplier and puts the result in the pixel width field, and multiplies the aspect height by the multiplier and puts the result in the pixel height field.

You can either enter an aspect ratio width and height and a multiplier and then click the “Calculate pixels” button, or enter your desired pixel dimensions and click the "Calculate aspect" button. If you enter pixel dimensions and click "Calculate aspect", ScopeWorks will reduce your pixel dimensions to an aspect ratio by removing all common factors from both numbers, and then calculate a multiplier that gives you the desired default pixel dimensions for your aspect ratio.

Once you have set up your new custom aspect ratio, click “Save” to add it to your list of available aspect ratios. (ScopeWorks saves your custom aspect ratios to its “User Defaults” settings. Your custom aspect ratios should persist between versions of ScopeWorks, but will be lost if you delete the program.)  
