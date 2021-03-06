// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/summary/format.dart';
import 'package:analyzer/src/summary/idl.dart';
import 'package:analyzer/src/summary2/link.dart';
import 'package:analyzer/src/summary2/linked_element_factory.dart';
import 'package:analyzer/src/summary2/linked_unit_context.dart';
import 'package:analyzer/src/summary2/reference.dart';

/// The context of a linked bundle, with shared references.
class LinkedBundleContext {
  final LinkedElementFactory elementFactory;
  final LinkedNodeBundle _bundle;
  final List<Reference> _references;
  final Map<String, LinkedLibraryContext> libraryMap = {};

  LinkedBundleContext(this.elementFactory, this._bundle)
      : _references = List<Reference>(_bundle.references.name.length) {
    for (var library in _bundle.libraries) {
      var libraryContext = LinkedLibraryContext(library.uriStr, this, library);
      libraryMap[library.uriStr] = libraryContext;

      var units = library.units;
      for (var unitIndex = 0; unitIndex < units.length; ++unitIndex) {
        var unit = units[unitIndex];
        var unitContext = LinkedUnitContext(
          this,
          libraryContext,
          unitIndex,
          unit.uriStr,
          unit,
        );
        libraryContext.units.add(unitContext);
      }
    }
  }

  LinkedBundleContext.forAst(this.elementFactory, this._references)
      : _bundle = null;

  LinkedLibraryContext addLinkingLibrary(
    String uriStr,
    LinkedNodeLibraryBuilder data,
    LinkInputLibrary inputLibrary,
  ) {
    var uriStr = data.uriStr;
    var libraryContext = LinkedLibraryContext(uriStr, this, data);
    libraryMap[uriStr] = libraryContext;

    var unitIndex = 0;
    for (var inputUnit in inputLibrary.units) {
      var source = inputUnit.source;
      var unitUriStr = source != null ? '${source.uri}' : '';
      libraryContext.units.add(
        LinkedUnitContext(
          this,
          libraryContext,
          unitIndex++,
          unitUriStr,
          null,
          unit: inputUnit.unit,
        ),
      );
    }
    return libraryContext;
  }

  T elementOfIndex<T extends Element>(int index) {
    var reference = referenceOfIndex(index);
    return elementFactory.elementOfReference(reference);
  }

  List<T> elementsOfIndexes<T extends Element>(List<int> indexList) {
    var result = List<T>(indexList.length);
    for (var i = 0; i < indexList.length; ++i) {
      var index = indexList[i];
      result[i] = elementOfIndex(index);
    }
    return result;
  }

  Reference referenceOfIndex(int index) {
    var reference = _references[index];
    if (reference != null) return reference;

    if (index == 0) {
      reference = elementFactory.rootReference;
      _references[index] = reference;
      return reference;
    }

    var parentIndex = _bundle.references.parent[index];
    var parent = referenceOfIndex(parentIndex);

    var name = _bundle.references.name[index];
    reference = parent.getChild(name);
    _references[index] = reference;

    return reference;
  }
}

class LinkedLibraryContext {
  final String uriStr;
  final LinkedBundleContext context;
  final LinkedNodeLibrary node;
  final List<LinkedUnitContext> units = [];

  LinkedLibraryContext(this.uriStr, this.context, this.node);

  LinkedUnitContext get definingUnit => units.first;
}
