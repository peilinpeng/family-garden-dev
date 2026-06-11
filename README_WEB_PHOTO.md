# Family Garden Web Photo Upload Patch

Replace:
- scripts/main.gd
- scripts/cloud_service.gd

This patch keeps desktop FileDialog upload and adds Web/GitHub Pages browser photo picking through JavaScriptBridge.

Export settings for GitHub Pages:
- Web export
- Thread Support: Off
- Renderer: Compatibility
- Export file name: index.html

Test locally with:
python3 -m http.server 8000
then open http://localhost:8000
