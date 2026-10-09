from pathlib import Path
import sys,html
sys.path.insert(0,str(Path('tests').resolve()))
from test_controls import WheelTests
from PIL import Image, ImageDraw, ImageFont
font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",12)
out=Path('previews');out.mkdir(exist_ok=True)
t=WheelTests();t.setUp();g=t.lua.globals();im=g.imgui
im.get_window_pos=lambda:t.lua.table_from({'x':0,'y':0})
for name,x,y in [('arsenal-centro',0,0),('arsenal-seleccion',0,1)]:
    shapes=[];points=[];cursor=[0,0]
    canvas=Image.new("RGB",(480,470),"#0b0d10");draw=ImageDraw.Draw(canvas)
    def col(n): return f'#{n&255:02x}{(n>>8)&255:02x}{(n>>16)&255:02x}'
    def clear(): points.clear()
    def point(p): points.append((p[1],p[2]))
    def stroke(c,closed,w):
        coords=points+[points[0]] if closed and points else points
        if len(coords)>1: draw.line(coords,fill=col(c),width=max(1,round(w)),joint="curve")
        shapes.append(f'<polyline points="{" ".join(f"{x:.2f},{y:.2f}" for x,y in coords)}" fill="none" stroke="{col(c)}" stroke-opacity="{((c>>24)&255)/255:.3f}" stroke-width="{w}" stroke-linejoin="round"/>')
    def cursor_set(p): cursor[:]=[p[1],p[2]]
    def text(s,c):
        draw.text(tuple(cursor),s,font=font,fill=col(c))
        shapes.append(f'<text x="{cursor[0]:.2f}" y="{cursor[1]+12:.2f}" fill="{col(c)}">{html.escape(s)}</text>')
    im.draw_list_path_clear=clear;im.draw_list_path_line_to=point;im.draw_list_path_stroke=stroke
    im.set_cursor_pos=cursor_set;im.text_colored=text
    t.poll(128,x,y)
    for _ in range(10): g.tick(None,.02)
    g.frame()
    svg='<svg xmlns="http://www.w3.org/2000/svg" width="480" height="470" viewBox="0 0 480 470"><rect width="480" height="470" fill="#0b0d10"/><g font-family="monospace" font-size="12">'+''.join(shapes)+'</g></svg>'
    (out/(name+'.svg')).write_text(svg,encoding='utf-8')
    canvas.save(out/(name+'.png'))
(out/'arsenal.html').write_text('<!doctype html><meta charset="utf-8"><title>Boltgun Sense — Arsenal</title><style>body{background:#090b0e;color:#decba1;font:16px monospace;margin:32px}main{display:flex;gap:24px}img{max-width:48vw}p{color:#999}</style><h1>BOLTGUN / SENSE — ARSENAL</h1><main><img src="arsenal-centro.svg"><img src="arsenal-seleccion.svg"></main><p>Dibujo generado ejecutando el renderer Lua. Vista de centro y selección superior; tipografía aproximada. Nombres de grupos verificados en los archivos del juego; no representan el inventario adquirido.</p>',encoding='utf-8')
print('Dos vistas generadas desde el renderer Lua.')
