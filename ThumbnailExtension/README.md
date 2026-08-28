# ScopeWorks Thumbnail Extension

QuickLook thumbnail extension so the iOS Files app and the in-app document
browser show each .ksp2 document's embedded preview (thumbnail.jpg inside the
document package) in icon views, falling back to the standard document icon
when a document has no embedded thumbnail.

Thumbnail extensions are a separate app-extension target, which must be
created in Xcode:

1. File → New → Target… → iOS → **Thumbnail Extension**.
   Name it `ScopeWorksThumbnails`, embed in ScopeWorks2. Do NOT activate a
   scheme for it when asked (not needed).
2. Delete the template's generated `ThumbnailProvider.swift` and add this
   folder's `ThumbnailProvider.swift` to the new target instead.
3. In the new target's Info.plist, set the supported content type to the
   ScopeWorks document type. Under
   `NSExtension → NSExtensionAttributes`:
   - `QLSupportedContentTypes` (array): one entry,
     `com.wareto.scopeworks2.document`
   - `QLThumbnailMinimumDimension` (number): `0`
4. Set the extension target's iOS deployment target to match the app's.
5. Build and run the app target on the iPad once so the system registers the
   extension.

Notes:
- Thumbnails appear in Files and in the document browser after the system
  regenerates its thumbnail cache; renaming or re-saving a file forces it.
- The extension reads `thumbnail.jpg` from inside the .ksp2 package. Documents
  saved with "Embed image thumbnails in documents" turned off (or legacy flat
  files) have none, and get the standard document icon.
