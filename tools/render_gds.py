# Render a GDS to PNG with KLayout (batch mode):
#   klayout -zz -r render_gds.py -rd gds=X.gds -rd lyp=sky130A.lyp -rd out=X.png
import pya

view = pya.LayoutView()
view.load_layout(gds, 0)
view.load_layer_props(lyp)
view.max_hier()
view.set_config("background-color", "#000000")
view.set_config("grid-visible", "false")
view.zoom_fit()
view.save_image(out, 2400, 1700)
