function slider_callback2(src,eventdata,arg1)
val = get(src,'Value');
set(arg1,'Position',[-val 0 1 2])