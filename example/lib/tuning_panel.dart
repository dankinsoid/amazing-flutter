// @ai-generated(solo)

import 'package:amazing_flutter/amazing_flutter.dart';
import 'package:flutter/material.dart';

typedef _Set = GlassMaterial Function(GlassMaterial m, double v);

class _Knob {
	const _Knob(this.label, this.min, this.max, this.get, this.set);

	final String label;
	final double min;
	final double max;
	final double Function(GlassMaterial m) get;
	final _Set set;
}

const _knobs = <(String, List<_Knob>)>[
	('Lens', [
		_Knob('height', 0, 30, _h, _sh),
		_Knob('edgeWidth', 1, 80, _ew, _sew),
		_Knob('thickness', 0, 100, _th, _sth),
		_Knob('aberration', 0, 0.6, _ab, _sab),
		_Knob('smoothK', 0, 80, _sk, _ssk),
	]),
	('Light', [
		_Knob('specular', 0, 2, _sp, _ssp),
		_Knob('shininess', 1, 200, _sh_, _ssh),
		_Knob('rim', 0, 2, _ri, _sri),
		_Knob('rimWidth', 0, 30, _rw, _srw),
		_Knob('fresnel', 0, 1, _fr, _sfr),
		_Knob('innerShadow', 0, 1, _is, _sis),
	]),
	('Floor', [
		_Knob('shadow', 0, 1, _sd, _ssd),
		_Knob('floorScale', 0, 4, _so, _sso),
		_Knob('caustic', 0, 2, _ca, _sca),
	]),
	('Color', [
		_Knob('tintStrength', 0, 1, _ts, _sts),
		_Knob('saturation', 0, 2, _sa, _ssa),
		_Knob('frostSigma', 0, 30, _fs, _sfs),
	]),
	('Water', [
		_Knob('rippleStrength', 0, 3, _rs, _srs),
		_Knob('wavelength', 6, 80, _wl, _swl),
		_Knob('frequency', 0.2, 8, _fq, _sfq),
		_Knob('reach', 20, 800, _re, _sre),
		_Knob('lifetime', 0.2, 5, _lt, _slt),
	]),
];

double _h(GlassMaterial m) => m.height;
GlassMaterial _sh(GlassMaterial m, double v) => m.copyWith(height: v);
double _ew(GlassMaterial m) => m.edgeWidth;
GlassMaterial _sew(GlassMaterial m, double v) => m.copyWith(edgeWidth: v);
double _th(GlassMaterial m) => m.thickness;
GlassMaterial _sth(GlassMaterial m, double v) => m.copyWith(thickness: v);
double _ab(GlassMaterial m) => m.aberration;
GlassMaterial _sab(GlassMaterial m, double v) => m.copyWith(aberration: v);
double _sk(GlassMaterial m) => m.smoothK;
GlassMaterial _ssk(GlassMaterial m, double v) => m.copyWith(smoothK: v);
double _sp(GlassMaterial m) => m.specular;
GlassMaterial _ssp(GlassMaterial m, double v) => m.copyWith(specular: v);
double _sh_(GlassMaterial m) => m.shininess;
GlassMaterial _ssh(GlassMaterial m, double v) => m.copyWith(shininess: v);
double _ri(GlassMaterial m) => m.rim;
GlassMaterial _sri(GlassMaterial m, double v) => m.copyWith(rim: v);
double _rw(GlassMaterial m) => m.rimWidth;
GlassMaterial _srw(GlassMaterial m, double v) => m.copyWith(rimWidth: v);
double _fr(GlassMaterial m) => m.fresnel;
GlassMaterial _sfr(GlassMaterial m, double v) => m.copyWith(fresnel: v);
double _is(GlassMaterial m) => m.innerShadow;
GlassMaterial _sis(GlassMaterial m, double v) => m.copyWith(innerShadow: v);
double _sd(GlassMaterial m) => m.shadow;
GlassMaterial _ssd(GlassMaterial m, double v) => m.copyWith(shadow: v);
double _so(GlassMaterial m) => m.floorScale;
GlassMaterial _sso(GlassMaterial m, double v) => m.copyWith(floorScale: v);
double _ca(GlassMaterial m) => m.caustic;
GlassMaterial _sca(GlassMaterial m, double v) => m.copyWith(caustic: v);
double _ts(GlassMaterial m) => m.tintStrength;
GlassMaterial _sts(GlassMaterial m, double v) => m.copyWith(tintStrength: v);
double _sa(GlassMaterial m) => m.saturation;
GlassMaterial _ssa(GlassMaterial m, double v) => m.copyWith(saturation: v);
double _fs(GlassMaterial m) => m.frostSigma;
GlassMaterial _sfs(GlassMaterial m, double v) => m.copyWith(frostSigma: v);
double _rs(GlassMaterial m) => m.rippleStrength;
GlassMaterial _srs(GlassMaterial m, double v) => m.copyWith(rippleStrength: v);
double _wl(GlassMaterial m) => m.wave.wavelength;
GlassMaterial _swl(GlassMaterial m, double v) => m.copyWith(wave: m.wave.copyWith(wavelength: v));
double _fq(GlassMaterial m) => m.wave.frequency;
GlassMaterial _sfq(GlassMaterial m, double v) => m.copyWith(wave: m.wave.copyWith(frequency: v));
double _re(GlassMaterial m) => m.wave.reach;
GlassMaterial _sre(GlassMaterial m, double v) => m.copyWith(wave: m.wave.copyWith(reach: v));
double _lt(GlassMaterial m) => m.wave.lifetime;
GlassMaterial _slt(GlassMaterial m, double v) => m.copyWith(wave: m.wave.copyWith(lifetime: v));

class _BodyKnob {
	const _BodyKnob(this.label, this.min, this.max, this.get, this.set);

	final String label;
	final double min;
	final double max;
	final double Function(ElasticBody b) get;
	final void Function(ElasticBody b, double v) set;
}

const _bodyKnobs = <_BodyKnob>[
	_BodyKnob('stiffness', 10, 600, _bst, _sbst),
	_BodyKnob('damping', 0, 40, _bda, _sbda),
	_BodyKnob('friction', 0, 20, _bfr, _sbfr),
	_BodyKnob('stretch/speed', 0, 0.003, _bsp, _sbsp),
	_BodyKnob('maxStretch', 0, 1.5, _bms, _sbms),
	_BodyKnob('pullGain', 0, 1.5, _bpg, _sbpg),
	_BodyKnob('pullRadius', 5, 150, _bpr, _sbpr),
];

double _bst(ElasticBody b) => b.stiffness;
void _sbst(ElasticBody b, double v) => b.stiffness = v;
double _bda(ElasticBody b) => b.damping;
void _sbda(ElasticBody b, double v) => b.damping = v;
double _bfr(ElasticBody b) => b.friction;
void _sbfr(ElasticBody b, double v) => b.friction = v;
double _bsp(ElasticBody b) => b.stretchPerSpeed;
void _sbsp(ElasticBody b, double v) => b.stretchPerSpeed = v;
double _bms(ElasticBody b) => b.maxStretch;
void _sbms(ElasticBody b, double v) => b.maxStretch = v;
double _bpg(ElasticBody b) => b.pullGain;
void _sbpg(ElasticBody b, double v) => b.pullGain = v;
double _bpr(ElasticBody b) => b.pullRadius;
void _sbpr(ElasticBody b, double v) => b.pullRadius = v;

class TuningPanel extends StatelessWidget {
	const TuningPanel({
		super.key,
		required this.material,
		required this.body,
		required this.onChanged,
		required this.onBodyChanged,
	});

	final GlassMaterial material;
	final ElasticBody body;
	final ValueChanged<GlassMaterial> onChanged;
	final VoidCallback onBodyChanged;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: 260,
			color: const Color(0xCC101418),
			child: ListView(
				padding: const EdgeInsets.symmetric(vertical: 8),
				children: [
					for (final (group, knobs) in _knobs) ...[
						Padding(
							padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
							child: Text(group, style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
						),
						for (final k in knobs) _row(k.label, k.get(material), k.min, k.max, (v) => onChanged(k.set(material, v))),
					],
					const Padding(
						padding: EdgeInsets.fromLTRB(12, 10, 12, 2),
						child: Text('Elastic', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1)),
					),
					for (final k in _bodyKnobs)
						_row(k.label, k.get(body), k.min, k.max, (v) {
							k.set(body, v);
							onBodyChanged();
						}),
				],
			),
		);
	}

	Widget _row(String label, double v, double min, double max, ValueChanged<double> set) {
		return SizedBox(
			height: 34,
			child: Row(
				children: [
					SizedBox(
						width: 96,
						child: Padding(
							padding: const EdgeInsets.only(left: 12),
							child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
						),
					),
					Expanded(
						child: SliderTheme(
							data: const SliderThemeData(trackHeight: 2, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6)),
							child: Slider(
								value: v.clamp(min, max),
								min: min,
								max: max,
								onChanged: set,
							),
						),
					),
					SizedBox(
						width: 44,
						child: Text(v.toStringAsFixed(v < 0.1 ? 4 : v < 10 ? 2 : 0), style: const TextStyle(color: Colors.white70, fontSize: 11)),
					),
				],
			),
		);
	}
}
