# rcpu-lang

_rcpu-lang_ (or _RCL_ for short) is a language that will compile to [RCPU](https://github.com/ddfreyne/rcpu) assembly.

Work in progress. Does not work at al yet.

The following is supported:

* <code>(print <var>var</var>)</code>
* <code>(print <var>num</var>)</code>
* <code>(let <var>var</var> <var>num</var>)</code>
* <code>(let <var>var</var> <var>var</var>)</code>
* <code>(halt)</code>
* <code>(seq <var>expr…</var>)</code>
* <code>(scoped-seq <var>expr…</var>)</code>
* <code>(if <var>op</var> <var>a</var> <var>b</var> <var>true-body</var> <var>false-body</var>)</code>

`op` can only be `eq` at the moment.
