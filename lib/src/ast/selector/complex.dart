// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../extend/functions.dart';
import '../../logger.dart';
import '../../parse/selector.dart';
import '../../utils.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A complex selector.
///
/// A complex selector is composed of [CompoundSelector]s separated by
/// [Combinator]s. It selects elements based on their parent selectors.
///
/// {@category Selector}
@sealed
class ComplexSelector extends Selector {
  /// The components of this selector.
  ///
  /// This is never empty.
  ///
  /// Descendant combinators aren't explicitly represented here. If two
  /// [CompoundSelector]s are adjacent to one another, there's an implicit
  /// descendant combinator between them.
  ///
  /// It's possible for multiple [Combinator]s to be adjacent to one another.
  /// This isn't valid CSS, but Sass supports it for CSS hack purposes.
  final List<ComplexSelectorComponent> components;

  /// Whether a line break should be emitted *before* this selector.
  ///
  /// @nodoc
  @internal
  final bool lineBreak;

  /// The minimum possible specificity that this selector can have.
  ///
  /// Pseudo selectors that contain selectors, like `:not()` and `:matches()`,
  /// can have a range of possible specificities.
  int get minSpecificity {
    if (_minSpecificity == null) _computeSpecificity();
    return _minSpecificity!;
  }

  int? _minSpecificity;

  /// The maximum possible specificity that this selector can have.
  ///
  /// Pseudo selectors that contain selectors, like `:not()` and `:matches()`,
  /// can have a range of possible specificities.
  int get maxSpecificity {
    if (_maxSpecificity == null) _computeSpecificity();
    return _maxSpecificity!;
  }

  int? _maxSpecificity;

  /// @nodoc
  @internal
  late final bool isInvisible = components.any(
      (component) => component is CompoundSelector && component.isInvisible);

  ComplexSelector(Iterable<ComplexSelectorComponent> components,
      {this.lineBreak = false})
      : components = List.unmodifiable(components) {
    if (this.components.isEmpty) {
      throw ArgumentError("components may not be empty.");
    }
  }

  /// Parses a complex selector from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  /// [allowParent] controls whether a [ParentSelector] is allowed in this
  /// selector.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory ComplexSelector.parse(String contents,
          {Object? url, Logger? logger, bool allowParent = true}) =>
      SelectorParser(contents,
              url: url, logger: logger, allowParent: allowParent)
          .parseComplexSelector();

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitComplexSelector(this);

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly matching more.
  bool isSuperselector(ComplexSelector other) =>
      complexIsSuperselector(components, other.components);

  /// Computes [_minSpecificity] and [_maxSpecificity].
  void _computeSpecificity() {
    var minSpecificity = 0;
    var maxSpecificity = 0;
    for (var component in components) {
      if (component is CompoundSelector) {
        minSpecificity += component.minSpecificity;
        maxSpecificity += component.maxSpecificity;
      }
    }
    _minSpecificity = minSpecificity;
    _maxSpecificity = maxSpecificity;
  }

  int get hashCode => listHash(components);

  bool operator ==(Object other) =>
      other is ComplexSelector && listEquals(components, other.components);
}

/// A component of a [ComplexSelector].
///
/// This is either a [CompoundSelector] or a [Combinator].
///
/// {@category Selector}
abstract class ComplexSelectorComponent {}

/// A combinator that defines the relationship between selectors in a
/// [ComplexSelector].
///
/// {@category Selector}
@sealed
class Combinator implements ComplexSelectorComponent {
  /// Matches the right-hand selector if it's immediately adjacent to the
  /// left-hand selector in the DOM tree.
  static const nextSibling = Combinator._("+");

  /// Matches the right-hand selector if it's a direct child of the left-hand
  /// selector in the DOM tree.
  static const child = Combinator._(">");

  /// Matches the right-hand selector if it comes after the left-hand selector
  /// in the DOM tree.
  static const followingSibling = Combinator._("~");

  /// The combinator's token text.
  final String _text;

  const Combinator._(this._text);

  String toString() => _text;
}
