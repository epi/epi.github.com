#!/usr/bin/env dub
/+ dub.sdl:
	name "plot"
	dependency "cairod" version="~>0.0.1-alpha.3+1.10.2"
	versions "CairoSVGSurface"
+/

import std.stdio;
import std.conv : to;

import cairo.svg;
import cairo.cairo;

struct Bar
{
	uint color;
	string label;
	double value;

	enum space = Bar.init;
}

void plot(string fname, string title, string xlabel, Bar[] bars...)
{
	import std.algorithm : filter, map, max, fold, sum;
	import std.range : array;
	import std.typecons : scoped;
	import std.string : format;

	enum width = 480;

	immutable maximum = bars
		.filter!(a => a.label.length)
		.map!(a => a.value)
		.fold!((a, b) => max(a, b));

	immutable height = bars
		.map!(a => a.label.length ? 18 : 9)
		.sum;

	auto surface = new SVGSurface(fname, width, height + 54);
	auto cr = Context(surface);
	cr.selectFontFace(
		"Arial",
		FontSlant.CAIRO_FONT_SLANT_NORMAL,
		FontWeight.CAIRO_FONT_WEIGHT_NORMAL);
	auto fe = cr.fontExtents();

	cr.setSourceRGB(0, 0, 0);
	cr.moveTo((width - cr.textExtents(title).width) / 2, fe.ascent);
	cr.showText(title);

	const text_values = bars
		.map!(bar => format("%.3g", bar.value))
		.array;
	const label_widths = bars
		.map!(bar => cr.textExtents(bar.label).x_advance)
		.array;
	immutable max_label_width = label_widths
		.fold!((a, b) => max(a, b));
	immutable max_value_width = text_values
		.map!(tv => cr.textExtents(tv).x_advance)
		.fold!((a, b) => max(a, b));
	immutable xscale =
		(width - max_label_width - max_value_width - 10) / maximum;

	// FIXME: compute step based on data
	immutable grid_step = 5;

	cr.setLineWidth(0.5);

	for (double x = 0; x < maximum; x += grid_step) {
		cr.moveTo(max_label_width + 5 + x * xscale, 4.5 + fe.height);
		cr.lineTo(max_label_width + 5 + x * xscale, height + 13.5 + fe.height);
		cr.stroke();
		string label = format("%.3g", x);
		cr.moveTo(
			max_label_width + 5 + x * xscale - cr.textExtents(label).width / 2,
			fe.height + height + 13.5 + fe.ascent);
		cr.setSourceRGB(0.6, 0.6, 0.6);
		cr.showText(label);
	}

	cr.moveTo((width - cr.textExtents(xlabel).width) / 2, height + 13.5 + fe.height * 2 + fe.ascent);
	cr.showText(xlabel);

	double ypos = fe.height + 9;
	enum rec = 1 / 255.0;
	foreach (i, bar; bars) {
		if (bar.label.length) {
			cr.setSourceRGB(0, 0, 0);
			cr.moveTo(
				max_label_width - label_widths[i],
				ypos + 9 - fe.descent + fe.height / 2);
			cr.showText(bar.label);
			cr.setSourceRGB(0.4, 0.4, 0.4);
			cr.moveTo(
				max_label_width + bar.value * xscale + 10,
				ypos + 9 - fe.descent + fe.height / 2);
			cr.showText(text_values[i]);
			cr.setSourceRGB(
				rec * ((bar.color >> 16) & 0xff),
				rec * ((bar.color >> 8) & 0xff),
				rec * (bar.color & 0xff));
			cr.rectangle(max_label_width + 5, ypos + 0.5, bar.value * xscale, 17);
			cr.fill();
			ypos += 18;
		} else {
			ypos += 9;
		}
	}
}

void main(string[] args)
{
	auto unordered_map = to!double(args[1]);
	auto hana_map     = to!double(args[2]);
	auto cpp_function = to!double(args[3]);
	auto d_linear     = to!double(args[4]);
	auto d_static     = to!double(args[5]);
	auto d_delegate   = to!double(args[6]);
	auto d_aa         = to!double(args[7]);
	auto d_map_template = to!double(args[8]);
	auto d_map_typeobj = to!double(args[9]);

	plot("hana.svg",
		"clang++ -O3 -flto",
		"time per call [ns], average of 500M calls, Core i7-3520M",
		Bar(0x5070d0, "unordered_map", unordered_map),
		Bar.space,
		Bar(0x5070d0, "hana::map", hana_map),
		Bar.space,
		Bar(0x5070d0, "std::function", cpp_function));

	plot("d.svg",
		"clang++ -O3 -flto / ldc2 -O3 -flto=full",
		"time per call [ns], average of 500M calls, Core i7-3520M",
		Bar(0x5070d0, "C++ unordered_map", unordered_map),
		Bar(0xff6060, "D foreach", d_linear),
		Bar.space,
		Bar(0x5070d0, "C++ hana::map", hana_map),
		Bar(0xff6060, "D staticIndexOf", d_static),
		Bar.space,
		Bar(0x5070d0, "C++ std::function", cpp_function),
		Bar(0xff6060, "D delegate", d_delegate));

	plot("dmap.svg",
		"clang++ -O3 -flto / ldc2 -O3 -flto=full",
		"time per call [ns], average of 500M calls, Core i7-3520M",
		Bar(0x5070d0, "C++ unordered_map", unordered_map),
		Bar(0xff6060, "D foreach", d_linear),
		Bar(0xffe060, "D AA", d_aa),
		Bar.space,
		Bar(0x5070d0, "C++ hana::map", hana_map),
		Bar(0xff6060, "D staticIndexOf", d_static),
		Bar(0xffe060, `D Map trigger!"foo"`, d_map_template),
		Bar(0xffe060, `D Map trigger(c!"foo")`, d_map_typeobj),
		Bar.space,
		Bar(0x5070d0, "C++ std::function", cpp_function),
		Bar(0xff6060, "D delegate", d_delegate));
}
