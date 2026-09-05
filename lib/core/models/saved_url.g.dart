// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_url.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSavedUrlCollection on Isar {
  IsarCollection<SavedUrl> get savedUrls => this.collection();
}

const SavedUrlSchema = CollectionSchema(
  name: r'SavedUrl',
  id: -157001970381558071,
  properties: {
    r'askNotes': PropertySchema(
      id: 0,
      name: r'askNotes',
      type: IsarType.objectList,
      target: r'SavedAskNote',
    ),
    r'categories': PropertySchema(
      id: 1,
      name: r'categories',
      type: IsarType.stringList,
    ),
    r'category': PropertySchema(
      id: 2,
      name: r'category',
      type: IsarType.string,
    ),
    r'categoryEmoji': PropertySchema(
      id: 3,
      name: r'categoryEmoji',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 4,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'description': PropertySchema(
      id: 5,
      name: r'description',
      type: IsarType.string,
    ),
    r'domain': PropertySchema(
      id: 6,
      name: r'domain',
      type: IsarType.string,
    ),
    r'effectiveCategories': PropertySchema(
      id: 7,
      name: r'effectiveCategories',
      type: IsarType.stringList,
    ),
    r'embedding': PropertySchema(
      id: 8,
      name: r'embedding',
      type: IsarType.doubleList,
    ),
    r'enrichmentJson': PropertySchema(
      id: 9,
      name: r'enrichmentJson',
      type: IsarType.string,
    ),
    r'highlightsJson': PropertySchema(
      id: 10,
      name: r'highlightsJson',
      type: IsarType.string,
    ),
    r'intentAction': PropertySchema(
      id: 11,
      name: r'intentAction',
      type: IsarType.string,
    ),
    r'intentSetAt': PropertySchema(
      id: 12,
      name: r'intentSetAt',
      type: IsarType.dateTime,
    ),
    r'intentStatus': PropertySchema(
      id: 13,
      name: r'intentStatus',
      type: IsarType.string,
    ),
    r'openedAt': PropertySchema(
      id: 14,
      name: r'openedAt',
      type: IsarType.dateTime,
    ),
    r'processingAttempt': PropertySchema(
      id: 15,
      name: r'processingAttempt',
      type: IsarType.long,
    ),
    r'processingError': PropertySchema(
      id: 16,
      name: r'processingError',
      type: IsarType.string,
    ),
    r'processingId': PropertySchema(
      id: 17,
      name: r'processingId',
      type: IsarType.string,
    ),
    r'processingStatus': PropertySchema(
      id: 18,
      name: r'processingStatus',
      type: IsarType.string,
    ),
    r'processingUpdatedAt': PropertySchema(
      id: 19,
      name: r'processingUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'rawUrl': PropertySchema(
      id: 20,
      name: r'rawUrl',
      type: IsarType.string,
    ),
    r'rediscoverDismissedAt': PropertySchema(
      id: 21,
      name: r'rediscoverDismissedAt',
      type: IsarType.dateTime,
    ),
    r'resurfacedAt': PropertySchema(
      id: 22,
      name: r'resurfacedAt',
      type: IsarType.dateTime,
    ),
    r'revisitAfter': PropertySchema(
      id: 23,
      name: r'revisitAfter',
      type: IsarType.dateTime,
    ),
    r'savedAt': PropertySchema(
      id: 24,
      name: r'savedAt',
      type: IsarType.dateTime,
    ),
    r'summary': PropertySchema(
      id: 25,
      name: r'summary',
      type: IsarType.string,
    ),
    r'tags': PropertySchema(
      id: 26,
      name: r'tags',
      type: IsarType.stringList,
    ),
    r'thumbnailUrl': PropertySchema(
      id: 27,
      name: r'thumbnailUrl',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 28,
      name: r'title',
      type: IsarType.string,
    ),
    r'userNotes': PropertySchema(
      id: 29,
      name: r'userNotes',
      type: IsarType.string,
    )
  },
  estimateSize: _savedUrlEstimateSize,
  serialize: _savedUrlSerialize,
  deserialize: _savedUrlDeserialize,
  deserializeProp: _savedUrlDeserializeProp,
  idName: r'id',
  indexes: {
    r'rawUrl': IndexSchema(
      id: 221252069567178676,
      name: r'rawUrl',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'rawUrl',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'title': IndexSchema(
      id: -7636685945352118059,
      name: r'title',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'title',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'category': IndexSchema(
      id: -7560358558326323820,
      name: r'category',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'category',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'deletedAt': IndexSchema(
      id: -8969437169173379604,
      name: r'deletedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'deletedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'intentStatus': IndexSchema(
      id: 6885063935731572498,
      name: r'intentStatus',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'intentStatus',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {r'SavedAskNote': SavedAskNoteSchema},
  getId: _savedUrlGetId,
  getLinks: _savedUrlGetLinks,
  attach: _savedUrlAttach,
  version: '3.1.0+1',
);

int _savedUrlEstimateSize(
  SavedUrl object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.askNotes.length * 3;
  {
    final offsets = allOffsets[SavedAskNote]!;
    for (var i = 0; i < object.askNotes.length; i++) {
      final value = object.askNotes[i];
      bytesCount += SavedAskNoteSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.categories.length * 3;
  {
    for (var i = 0; i < object.categories.length; i++) {
      final value = object.categories[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.categoryEmoji.length * 3;
  bytesCount += 3 + object.description.length * 3;
  bytesCount += 3 + object.domain.length * 3;
  bytesCount += 3 + object.effectiveCategories.length * 3;
  {
    for (var i = 0; i < object.effectiveCategories.length; i++) {
      final value = object.effectiveCategories[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.embedding;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  {
    final value = object.enrichmentJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.highlightsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.intentAction;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.intentStatus;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.processingError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.processingId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.processingStatus;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.rawUrl.length * 3;
  {
    final value = object.summary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.thumbnailUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.userNotes;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _savedUrlSerialize(
  SavedUrl object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeObjectList<SavedAskNote>(
    offsets[0],
    allOffsets,
    SavedAskNoteSchema.serialize,
    object.askNotes,
  );
  writer.writeStringList(offsets[1], object.categories);
  writer.writeString(offsets[2], object.category);
  writer.writeString(offsets[3], object.categoryEmoji);
  writer.writeDateTime(offsets[4], object.deletedAt);
  writer.writeString(offsets[5], object.description);
  writer.writeString(offsets[6], object.domain);
  writer.writeStringList(offsets[7], object.effectiveCategories);
  writer.writeDoubleList(offsets[8], object.embedding);
  writer.writeString(offsets[9], object.enrichmentJson);
  writer.writeString(offsets[10], object.highlightsJson);
  writer.writeString(offsets[11], object.intentAction);
  writer.writeDateTime(offsets[12], object.intentSetAt);
  writer.writeString(offsets[13], object.intentStatus);
  writer.writeDateTime(offsets[14], object.openedAt);
  writer.writeLong(offsets[15], object.processingAttempt);
  writer.writeString(offsets[16], object.processingError);
  writer.writeString(offsets[17], object.processingId);
  writer.writeString(offsets[18], object.processingStatus);
  writer.writeDateTime(offsets[19], object.processingUpdatedAt);
  writer.writeString(offsets[20], object.rawUrl);
  writer.writeDateTime(offsets[21], object.rediscoverDismissedAt);
  writer.writeDateTime(offsets[22], object.resurfacedAt);
  writer.writeDateTime(offsets[23], object.revisitAfter);
  writer.writeDateTime(offsets[24], object.savedAt);
  writer.writeString(offsets[25], object.summary);
  writer.writeStringList(offsets[26], object.tags);
  writer.writeString(offsets[27], object.thumbnailUrl);
  writer.writeString(offsets[28], object.title);
  writer.writeString(offsets[29], object.userNotes);
}

SavedUrl _savedUrlDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SavedUrl();
  object.askNotes = reader.readObjectList<SavedAskNote>(
        offsets[0],
        SavedAskNoteSchema.deserialize,
        allOffsets,
        SavedAskNote(),
      ) ??
      [];
  object.categories = reader.readStringList(offsets[1]) ?? [];
  object.category = reader.readString(offsets[2]);
  object.categoryEmoji = reader.readString(offsets[3]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[4]);
  object.description = reader.readString(offsets[5]);
  object.domain = reader.readString(offsets[6]);
  object.embedding = reader.readDoubleList(offsets[8]);
  object.enrichmentJson = reader.readStringOrNull(offsets[9]);
  object.highlightsJson = reader.readStringOrNull(offsets[10]);
  object.id = id;
  object.intentAction = reader.readStringOrNull(offsets[11]);
  object.intentSetAt = reader.readDateTimeOrNull(offsets[12]);
  object.intentStatus = reader.readStringOrNull(offsets[13]);
  object.openedAt = reader.readDateTimeOrNull(offsets[14]);
  object.processingAttempt = reader.readLongOrNull(offsets[15]);
  object.processingError = reader.readStringOrNull(offsets[16]);
  object.processingId = reader.readStringOrNull(offsets[17]);
  object.processingStatus = reader.readStringOrNull(offsets[18]);
  object.processingUpdatedAt = reader.readDateTimeOrNull(offsets[19]);
  object.rawUrl = reader.readString(offsets[20]);
  object.rediscoverDismissedAt = reader.readDateTimeOrNull(offsets[21]);
  object.resurfacedAt = reader.readDateTimeOrNull(offsets[22]);
  object.revisitAfter = reader.readDateTimeOrNull(offsets[23]);
  object.savedAt = reader.readDateTime(offsets[24]);
  object.summary = reader.readStringOrNull(offsets[25]);
  object.tags = reader.readStringList(offsets[26]) ?? [];
  object.thumbnailUrl = reader.readStringOrNull(offsets[27]);
  object.title = reader.readString(offsets[28]);
  object.userNotes = reader.readStringOrNull(offsets[29]);
  return object;
}

P _savedUrlDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readObjectList<SavedAskNote>(
            offset,
            SavedAskNoteSchema.deserialize,
            allOffsets,
            SavedAskNote(),
          ) ??
          []) as P;
    case 1:
      return (reader.readStringList(offset) ?? []) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringList(offset) ?? []) as P;
    case 8:
      return (reader.readDoubleList(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 15:
      return (reader.readLongOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readStringOrNull(offset)) as P;
    case 19:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 20:
      return (reader.readString(offset)) as P;
    case 21:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 22:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 23:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 24:
      return (reader.readDateTime(offset)) as P;
    case 25:
      return (reader.readStringOrNull(offset)) as P;
    case 26:
      return (reader.readStringList(offset) ?? []) as P;
    case 27:
      return (reader.readStringOrNull(offset)) as P;
    case 28:
      return (reader.readString(offset)) as P;
    case 29:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _savedUrlGetId(SavedUrl object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _savedUrlGetLinks(SavedUrl object) {
  return [];
}

void _savedUrlAttach(IsarCollection<dynamic> col, Id id, SavedUrl object) {
  object.id = id;
}

extension SavedUrlQueryWhereSort on QueryBuilder<SavedUrl, SavedUrl, QWhere> {
  QueryBuilder<SavedUrl, SavedUrl, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhere> anyTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'title'),
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhere> anyDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'deletedAt'),
      );
    });
  }
}

extension SavedUrlQueryWhere on QueryBuilder<SavedUrl, SavedUrl, QWhereClause> {
  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> rawUrlEqualTo(
      String rawUrl) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'rawUrl',
        value: [rawUrl],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> rawUrlNotEqualTo(
      String rawUrl) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rawUrl',
              lower: [],
              upper: [rawUrl],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rawUrl',
              lower: [rawUrl],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rawUrl',
              lower: [rawUrl],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'rawUrl',
              lower: [],
              upper: [rawUrl],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleEqualTo(
      String title) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'title',
        value: [title],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleNotEqualTo(
      String title) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [],
              upper: [title],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [title],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [title],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'title',
              lower: [],
              upper: [title],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleGreaterThan(
    String title, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'title',
        lower: [title],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleLessThan(
    String title, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'title',
        lower: [],
        upper: [title],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleBetween(
    String lowerTitle,
    String upperTitle, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'title',
        lower: [lowerTitle],
        includeLower: includeLower,
        upper: [upperTitle],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleStartsWith(
      String TitlePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'title',
        lower: [TitlePrefix],
        upper: ['$TitlePrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'title',
        value: [''],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'title',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'title',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'title',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'title',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> categoryEqualTo(
      String category) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'category',
        value: [category],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> categoryNotEqualTo(
      String category) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [],
              upper: [category],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [category],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [category],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'category',
              lower: [],
              upper: [category],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'deletedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'deletedAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtEqualTo(
      DateTime? deletedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'deletedAt',
        value: [deletedAt],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtNotEqualTo(
      DateTime? deletedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deletedAt',
              lower: [],
              upper: [deletedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deletedAt',
              lower: [deletedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deletedAt',
              lower: [deletedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deletedAt',
              lower: [],
              upper: [deletedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtGreaterThan(
    DateTime? deletedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'deletedAt',
        lower: [deletedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtLessThan(
    DateTime? deletedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'deletedAt',
        lower: [],
        upper: [deletedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> deletedAtBetween(
    DateTime? lowerDeletedAt,
    DateTime? upperDeletedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'deletedAt',
        lower: [lowerDeletedAt],
        includeLower: includeLower,
        upper: [upperDeletedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> intentStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'intentStatus',
        value: [null],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> intentStatusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'intentStatus',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> intentStatusEqualTo(
      String? intentStatus) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'intentStatus',
        value: [intentStatus],
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterWhereClause> intentStatusNotEqualTo(
      String? intentStatus) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'intentStatus',
              lower: [],
              upper: [intentStatus],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'intentStatus',
              lower: [intentStatus],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'intentStatus',
              lower: [intentStatus],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'intentStatus',
              lower: [],
              upper: [intentStatus],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SavedUrlQueryFilter
    on QueryBuilder<SavedUrl, SavedUrl, QFilterCondition> {
  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> askNotesLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'askNotes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> askNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'askNotes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> askNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'askNotes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      askNotesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'askNotes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      askNotesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'askNotes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> askNotesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'askNotes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'categories',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'categories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'categories',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categories',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'categories',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoriesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoriesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'categories',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEmojiEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categoryEmoji',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoryEmojiGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'categoryEmoji',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEmojiLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'categoryEmoji',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEmojiBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'categoryEmoji',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoryEmojiStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'categoryEmoji',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEmojiEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'categoryEmoji',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEmojiContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'categoryEmoji',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> categoryEmojiMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'categoryEmoji',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoryEmojiIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'categoryEmoji',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      categoryEmojiIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'categoryEmoji',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> deletedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> deletedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> deletedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      descriptionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'domain',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'domain',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'domain',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'domain',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> domainIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'domain',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'effectiveCategories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'effectiveCategories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'effectiveCategories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'effectiveCategories',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'effectiveCategories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'effectiveCategories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'effectiveCategories',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'effectiveCategories',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'effectiveCategories',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'effectiveCategories',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'effectiveCategories',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'effectiveCategories',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'effectiveCategories',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'effectiveCategories',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'effectiveCategories',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      effectiveCategoriesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'effectiveCategories',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> embeddingIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'embedding',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> embeddingIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'embedding',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'embedding',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> embeddingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      embeddingLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'enrichmentJson',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'enrichmentJson',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> enrichmentJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'enrichmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'enrichmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'enrichmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> enrichmentJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'enrichmentJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'enrichmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'enrichmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'enrichmentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> enrichmentJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'enrichmentJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'enrichmentJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      enrichmentJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'enrichmentJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'highlightsJson',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'highlightsJson',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> highlightsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'highlightsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'highlightsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'highlightsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> highlightsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'highlightsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'highlightsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'highlightsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'highlightsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> highlightsJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'highlightsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'highlightsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      highlightsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'highlightsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'intentAction',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentActionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'intentAction',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intentAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentActionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'intentAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'intentAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'intentAction',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentActionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'intentAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'intentAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'intentAction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentActionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'intentAction',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentActionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intentAction',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentActionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'intentAction',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentSetAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'intentSetAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentSetAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'intentSetAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentSetAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intentSetAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentSetAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'intentSetAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentSetAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'intentSetAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentSetAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'intentSetAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'intentStatus',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentStatusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'intentStatus',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intentStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentStatusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'intentStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'intentStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'intentStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'intentStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'intentStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'intentStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> intentStatusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'intentStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intentStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      intentStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'intentStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> openedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'openedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> openedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'openedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> openedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> openedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> openedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> openedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'openedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingAttemptIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'processingAttempt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingAttemptIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'processingAttempt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingAttemptEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingAttemptGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'processingAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingAttemptLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'processingAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingAttemptBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'processingAttempt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'processingError',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'processingError',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'processingError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'processingError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'processingError',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'processingError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'processingError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'processingError',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'processingError',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingError',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'processingError',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'processingId',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'processingId',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'processingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'processingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'processingId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'processingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'processingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'processingId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> processingIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'processingId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingId',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'processingId',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'processingStatus',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'processingStatus',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'processingStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'processingStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'processingStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'processingStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'processingStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'processingStatus',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'processingStatus',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingStatusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'processingStatus',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingUpdatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'processingUpdatedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingUpdatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'processingUpdatedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingUpdatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'processingUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingUpdatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'processingUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingUpdatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'processingUpdatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      processingUpdatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'processingUpdatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> rawUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      rediscoverDismissedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'rediscoverDismissedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      rediscoverDismissedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'rediscoverDismissedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      rediscoverDismissedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rediscoverDismissedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      rediscoverDismissedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rediscoverDismissedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      rediscoverDismissedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rediscoverDismissedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      rediscoverDismissedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rediscoverDismissedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> resurfacedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'resurfacedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      resurfacedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'resurfacedAt',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> resurfacedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'resurfacedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      resurfacedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'resurfacedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> resurfacedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'resurfacedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> resurfacedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'resurfacedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> revisitAfterIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'revisitAfter',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      revisitAfterIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'revisitAfter',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> revisitAfterEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'revisitAfter',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      revisitAfterGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'revisitAfter',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> revisitAfterLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'revisitAfter',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> revisitAfterBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'revisitAfter',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> savedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'savedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> savedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'savedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> savedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'savedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> savedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'savedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'summary',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'summary',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'summary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'summary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> summaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'thumbnailUrl',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      thumbnailUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'thumbnailUrl',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'thumbnailUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      thumbnailUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'thumbnailUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'thumbnailUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'thumbnailUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      thumbnailUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'thumbnailUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'thumbnailUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'thumbnailUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> thumbnailUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'thumbnailUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      thumbnailUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'thumbnailUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      thumbnailUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'thumbnailUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'userNotes',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'userNotes',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userNotes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userNotes',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userNotes',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> userNotesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userNotes',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition>
      userNotesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userNotes',
        value: '',
      ));
    });
  }
}

extension SavedUrlQueryObject
    on QueryBuilder<SavedUrl, SavedUrl, QFilterCondition> {
  QueryBuilder<SavedUrl, SavedUrl, QAfterFilterCondition> askNotesElement(
      FilterQuery<SavedAskNote> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'askNotes');
    });
  }
}

extension SavedUrlQueryLinks
    on QueryBuilder<SavedUrl, SavedUrl, QFilterCondition> {}

extension SavedUrlQuerySortBy on QueryBuilder<SavedUrl, SavedUrl, QSortBy> {
  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByCategoryEmoji() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryEmoji', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByCategoryEmojiDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryEmoji', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByEnrichmentJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentJson', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByEnrichmentJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentJson', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByHighlightsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'highlightsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByHighlightsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'highlightsJson', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByIntentAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentAction', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByIntentActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentAction', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByIntentSetAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentSetAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByIntentSetAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentSetAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByIntentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentStatus', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByIntentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentStatus', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingAttempt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingAttemptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingAttempt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingError', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingError', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingId', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingId', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingStatus', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingStatus', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByProcessingUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy>
      sortByProcessingUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByRawUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawUrl', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByRawUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawUrl', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByRediscoverDismissedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rediscoverDismissedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy>
      sortByRediscoverDismissedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rediscoverDismissedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByResurfacedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resurfacedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByResurfacedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resurfacedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByRevisitAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revisitAfter', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByRevisitAfterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revisitAfter', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortBySavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByThumbnailUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUrl', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByThumbnailUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUrl', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByUserNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userNotes', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> sortByUserNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userNotes', Sort.desc);
    });
  }
}

extension SavedUrlQuerySortThenBy
    on QueryBuilder<SavedUrl, SavedUrl, QSortThenBy> {
  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByCategoryEmoji() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryEmoji', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByCategoryEmojiDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryEmoji', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByDomain() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByDomainDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'domain', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByEnrichmentJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentJson', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByEnrichmentJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enrichmentJson', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByHighlightsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'highlightsJson', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByHighlightsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'highlightsJson', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIntentAction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentAction', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIntentActionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentAction', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIntentSetAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentSetAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIntentSetAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentSetAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIntentStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentStatus', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByIntentStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intentStatus', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingAttempt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingAttemptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingAttempt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingError', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingError', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingId', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingId', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingStatus', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingStatus', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByProcessingUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy>
      thenByProcessingUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'processingUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByRawUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawUrl', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByRawUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawUrl', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByRediscoverDismissedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rediscoverDismissedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy>
      thenByRediscoverDismissedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rediscoverDismissedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByResurfacedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resurfacedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByResurfacedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'resurfacedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByRevisitAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revisitAfter', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByRevisitAfterDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revisitAfter', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedAt', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenBySavedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'savedAt', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByThumbnailUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUrl', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByThumbnailUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbnailUrl', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByUserNotes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userNotes', Sort.asc);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QAfterSortBy> thenByUserNotesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userNotes', Sort.desc);
    });
  }
}

extension SavedUrlQueryWhereDistinct
    on QueryBuilder<SavedUrl, SavedUrl, QDistinct> {
  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByCategories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categories');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByCategoryEmoji(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryEmoji',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByDescription(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByDomain(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'domain', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByEffectiveCategories() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'effectiveCategories');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByEmbedding() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'embedding');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByEnrichmentJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enrichmentJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByHighlightsJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'highlightsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByIntentAction(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intentAction', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByIntentSetAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intentSetAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByIntentStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intentStatus', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openedAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByProcessingAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'processingAttempt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByProcessingError(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'processingError',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByProcessingId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'processingId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByProcessingStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'processingStatus',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByProcessingUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'processingUpdatedAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByRawUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct>
      distinctByRediscoverDismissedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rediscoverDismissedAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByResurfacedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'resurfacedAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByRevisitAfter() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revisitAfter');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctBySavedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'savedAt');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctBySummary(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summary', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByThumbnailUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'thumbnailUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavedUrl, SavedUrl, QDistinct> distinctByUserNotes(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userNotes', caseSensitive: caseSensitive);
    });
  }
}

extension SavedUrlQueryProperty
    on QueryBuilder<SavedUrl, SavedUrl, QQueryProperty> {
  QueryBuilder<SavedUrl, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SavedUrl, List<SavedAskNote>, QQueryOperations>
      askNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'askNotes');
    });
  }

  QueryBuilder<SavedUrl, List<String>, QQueryOperations> categoriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categories');
    });
  }

  QueryBuilder<SavedUrl, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<SavedUrl, String, QQueryOperations> categoryEmojiProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryEmoji');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<SavedUrl, String, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<SavedUrl, String, QQueryOperations> domainProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'domain');
    });
  }

  QueryBuilder<SavedUrl, List<String>, QQueryOperations>
      effectiveCategoriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'effectiveCategories');
    });
  }

  QueryBuilder<SavedUrl, List<double>?, QQueryOperations> embeddingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embedding');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> enrichmentJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enrichmentJson');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> highlightsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'highlightsJson');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> intentActionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intentAction');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations> intentSetAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intentSetAt');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> intentStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intentStatus');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations> openedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openedAt');
    });
  }

  QueryBuilder<SavedUrl, int?, QQueryOperations> processingAttemptProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'processingAttempt');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> processingErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'processingError');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> processingIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'processingId');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> processingStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'processingStatus');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations>
      processingUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'processingUpdatedAt');
    });
  }

  QueryBuilder<SavedUrl, String, QQueryOperations> rawUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawUrl');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations>
      rediscoverDismissedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rediscoverDismissedAt');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations> resurfacedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'resurfacedAt');
    });
  }

  QueryBuilder<SavedUrl, DateTime?, QQueryOperations> revisitAfterProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revisitAfter');
    });
  }

  QueryBuilder<SavedUrl, DateTime, QQueryOperations> savedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'savedAt');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> summaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summary');
    });
  }

  QueryBuilder<SavedUrl, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> thumbnailUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'thumbnailUrl');
    });
  }

  QueryBuilder<SavedUrl, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<SavedUrl, String?, QQueryOperations> userNotesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userNotes');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const SavedAskNoteSchema = Schema(
  name: r'SavedAskNote',
  id: -6635258813739158306,
  properties: {
    r'body': PropertySchema(
      id: 0,
      name: r'body',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'id': PropertySchema(
      id: 2,
      name: r'id',
      type: IsarType.string,
    ),
    r'question': PropertySchema(
      id: 3,
      name: r'question',
      type: IsarType.string,
    ),
    r'sourceMessageId': PropertySchema(
      id: 4,
      name: r'sourceMessageId',
      type: IsarType.string,
    )
  },
  estimateSize: _savedAskNoteEstimateSize,
  serialize: _savedAskNoteSerialize,
  deserialize: _savedAskNoteDeserialize,
  deserializeProp: _savedAskNoteDeserializeProp,
);

int _savedAskNoteEstimateSize(
  SavedAskNote object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.body.length * 3;
  bytesCount += 3 + object.id.length * 3;
  bytesCount += 3 + object.question.length * 3;
  {
    final value = object.sourceMessageId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _savedAskNoteSerialize(
  SavedAskNote object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.body);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.id);
  writer.writeString(offsets[3], object.question);
  writer.writeString(offsets[4], object.sourceMessageId);
}

SavedAskNote _savedAskNoteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SavedAskNote();
  object.body = reader.readString(offsets[0]);
  object.createdAt = reader.readDateTimeOrNull(offsets[1]);
  object.id = reader.readString(offsets[2]);
  object.question = reader.readString(offsets[3]);
  object.sourceMessageId = reader.readStringOrNull(offsets[4]);
  return object;
}

P _savedAskNoteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension SavedAskNoteQueryFilter
    on QueryBuilder<SavedAskNote, SavedAskNote, QFilterCondition> {
  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> bodyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'body',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      bodyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'body',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> bodyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'body',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> bodyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'body',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      bodyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'body',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> bodyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'body',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> bodyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'body',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> bodyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'body',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      bodyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'body',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      bodyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'body',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      createdAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      createdAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'question',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'question',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'question',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'question',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      questionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'question',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sourceMessageId',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sourceMessageId',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceMessageId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceMessageId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceMessageId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceMessageId',
        value: '',
      ));
    });
  }

  QueryBuilder<SavedAskNote, SavedAskNote, QAfterFilterCondition>
      sourceMessageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceMessageId',
        value: '',
      ));
    });
  }
}

extension SavedAskNoteQueryObject
    on QueryBuilder<SavedAskNote, SavedAskNote, QFilterCondition> {}
