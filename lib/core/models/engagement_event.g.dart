// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engagement_event.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEngagementEventCollection on Isar {
  IsarCollection<EngagementEvent> get engagementEvents => this.collection();
}

const EngagementEventSchema = CollectionSchema(
  name: r'EngagementEvent',
  id: -6627596575612022261,
  properties: {
    r'at': PropertySchema(
      id: 0,
      name: r'at',
      type: IsarType.dateTime,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'clusterLabel': PropertySchema(
      id: 2,
      name: r'clusterLabel',
      type: IsarType.string,
    ),
    r'hourLocal': PropertySchema(
      id: 3,
      name: r'hourLocal',
      type: IsarType.long,
    ),
    r'query': PropertySchema(
      id: 4,
      name: r'query',
      type: IsarType.string,
    ),
    r'source': PropertySchema(
      id: 5,
      name: r'source',
      type: IsarType.string,
    ),
    r'triggerType': PropertySchema(
      id: 6,
      name: r'triggerType',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 7,
      name: r'type',
      type: IsarType.string,
      enumMap: _EngagementEventtypeEnumValueMap,
    ),
    r'urlId': PropertySchema(
      id: 8,
      name: r'urlId',
      type: IsarType.long,
    )
  },
  estimateSize: _engagementEventEstimateSize,
  serialize: _engagementEventSerialize,
  deserialize: _engagementEventDeserialize,
  deserializeProp: _engagementEventDeserializeProp,
  idName: r'id',
  indexes: {
    r'at': IndexSchema(
      id: 1454144528255648370,
      name: r'at',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'at',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _engagementEventGetId,
  getLinks: _engagementEventGetLinks,
  attach: _engagementEventAttach,
  version: '3.1.0+1',
);

int _engagementEventEstimateSize(
  EngagementEvent object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.category;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.clusterLabel;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.query;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.source;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.triggerType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.type.name.length * 3;
  return bytesCount;
}

void _engagementEventSerialize(
  EngagementEvent object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.at);
  writer.writeString(offsets[1], object.category);
  writer.writeString(offsets[2], object.clusterLabel);
  writer.writeLong(offsets[3], object.hourLocal);
  writer.writeString(offsets[4], object.query);
  writer.writeString(offsets[5], object.source);
  writer.writeString(offsets[6], object.triggerType);
  writer.writeString(offsets[7], object.type.name);
  writer.writeLong(offsets[8], object.urlId);
}

EngagementEvent _engagementEventDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = EngagementEvent();
  object.at = reader.readDateTime(offsets[0]);
  object.category = reader.readStringOrNull(offsets[1]);
  object.clusterLabel = reader.readStringOrNull(offsets[2]);
  object.hourLocal = reader.readLong(offsets[3]);
  object.id = id;
  object.query = reader.readStringOrNull(offsets[4]);
  object.source = reader.readStringOrNull(offsets[5]);
  object.triggerType = reader.readStringOrNull(offsets[6]);
  object.type =
      _EngagementEventtypeValueEnumMap[reader.readStringOrNull(offsets[7])] ??
          EngagementEventType.save;
  object.urlId = reader.readLongOrNull(offsets[8]);
  return object;
}

P _engagementEventDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (_EngagementEventtypeValueEnumMap[
              reader.readStringOrNull(offset)] ??
          EngagementEventType.save) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _EngagementEventtypeEnumValueMap = {
  r'save': r'save',
  r'open': r'open',
  r'tapThrough': r'tapThrough',
  r'search': r'search',
  r'searchHit': r'searchHit',
  r'categoryVisit': r'categoryVisit',
  r'clusterVisit': r'clusterVisit',
  r'cardShown': r'cardShown',
  r'cardOpened': r'cardOpened',
  r'cardDismissed': r'cardDismissed',
  r'cardSnoozed': r'cardSnoozed',
  r'notifShown': r'notifShown',
  r'notifOpened': r'notifOpened',
  r'notifDismissed': r'notifDismissed',
  r'intentSet': r'intentSet',
};
const _EngagementEventtypeValueEnumMap = {
  r'save': EngagementEventType.save,
  r'open': EngagementEventType.open,
  r'tapThrough': EngagementEventType.tapThrough,
  r'search': EngagementEventType.search,
  r'searchHit': EngagementEventType.searchHit,
  r'categoryVisit': EngagementEventType.categoryVisit,
  r'clusterVisit': EngagementEventType.clusterVisit,
  r'cardShown': EngagementEventType.cardShown,
  r'cardOpened': EngagementEventType.cardOpened,
  r'cardDismissed': EngagementEventType.cardDismissed,
  r'cardSnoozed': EngagementEventType.cardSnoozed,
  r'notifShown': EngagementEventType.notifShown,
  r'notifOpened': EngagementEventType.notifOpened,
  r'notifDismissed': EngagementEventType.notifDismissed,
  r'intentSet': EngagementEventType.intentSet,
};

Id _engagementEventGetId(EngagementEvent object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _engagementEventGetLinks(EngagementEvent object) {
  return [];
}

void _engagementEventAttach(
    IsarCollection<dynamic> col, Id id, EngagementEvent object) {
  object.id = id;
}

extension EngagementEventQueryWhereSort
    on QueryBuilder<EngagementEvent, EngagementEvent, QWhere> {
  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhere> anyAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'at'),
      );
    });
  }
}

extension EngagementEventQueryWhere
    on QueryBuilder<EngagementEvent, EngagementEvent, QWhereClause> {
  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause> idBetween(
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause> atEqualTo(
      DateTime at) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'at',
        value: [at],
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause>
      atNotEqualTo(DateTime at) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'at',
              lower: [],
              upper: [at],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'at',
              lower: [at],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'at',
              lower: [at],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'at',
              lower: [],
              upper: [at],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause>
      atGreaterThan(
    DateTime at, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'at',
        lower: [at],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause> atLessThan(
    DateTime at, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'at',
        lower: [],
        upper: [at],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterWhereClause> atBetween(
    DateTime lowerAt,
    DateTime upperAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'at',
        lower: [lowerAt],
        includeLower: includeLower,
        upper: [upperAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension EngagementEventQueryFilter
    on QueryBuilder<EngagementEvent, EngagementEvent, QFilterCondition> {
  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      atEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'at',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      atGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'at',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      atLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'at',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      atBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'at',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'category',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'category',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryEqualTo(
    String? value, {
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryGreaterThan(
    String? value, {
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryLessThan(
    String? value, {
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryStartsWith(
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryEndsWith(
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'clusterLabel',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'clusterLabel',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clusterLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'clusterLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'clusterLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'clusterLabel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'clusterLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'clusterLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'clusterLabel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'clusterLabel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clusterLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      clusterLabelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'clusterLabel',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      hourLocalEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hourLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      hourLocalGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'hourLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      hourLocalLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'hourLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      hourLocalBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'hourLocal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'query',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'query',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'query',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'query',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'query',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'query',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      queryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'query',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'source',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'source',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'source',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'source',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'source',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'source',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      sourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'source',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'triggerType',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'triggerType',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'triggerType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'triggerType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'triggerType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'triggerType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'triggerType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'triggerType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'triggerType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'triggerType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'triggerType',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      triggerTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'triggerType',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeEqualTo(
    EngagementEventType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeGreaterThan(
    EngagementEventType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeLessThan(
    EngagementEventType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeBetween(
    EngagementEventType lower,
    EngagementEventType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'type',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'type',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'type',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'type',
        value: '',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      urlIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'urlId',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      urlIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'urlId',
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      urlIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'urlId',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      urlIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'urlId',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      urlIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'urlId',
        value: value,
      ));
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterFilterCondition>
      urlIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'urlId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension EngagementEventQueryObject
    on QueryBuilder<EngagementEvent, EngagementEvent, QFilterCondition> {}

extension EngagementEventQueryLinks
    on QueryBuilder<EngagementEvent, EngagementEvent, QFilterCondition> {}

extension EngagementEventQuerySortBy
    on QueryBuilder<EngagementEvent, EngagementEvent, QSortBy> {
  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> sortByAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'at', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> sortByAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'at', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByClusterLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterLabel', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByClusterLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterLabel', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByHourLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hourLocal', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByHourLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hourLocal', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> sortByQuery() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByQueryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> sortBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByTriggerType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerType', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByTriggerTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerType', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> sortByUrlId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'urlId', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      sortByUrlIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'urlId', Sort.desc);
    });
  }
}

extension EngagementEventQuerySortThenBy
    on QueryBuilder<EngagementEvent, EngagementEvent, QSortThenBy> {
  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenByAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'at', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenByAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'at', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByClusterLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterLabel', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByClusterLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clusterLabel', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByHourLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hourLocal', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByHourLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hourLocal', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenByQuery() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByQueryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'query', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'source', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByTriggerType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerType', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByTriggerTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'triggerType', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy> thenByUrlId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'urlId', Sort.asc);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QAfterSortBy>
      thenByUrlIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'urlId', Sort.desc);
    });
  }
}

extension EngagementEventQueryWhereDistinct
    on QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> {
  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> distinctByAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'at');
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> distinctByCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct>
      distinctByClusterLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clusterLabel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct>
      distinctByHourLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hourLocal');
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> distinctByQuery(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'query', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> distinctBySource(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'source', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct>
      distinctByTriggerType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'triggerType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> distinctByType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<EngagementEvent, EngagementEvent, QDistinct> distinctByUrlId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'urlId');
    });
  }
}

extension EngagementEventQueryProperty
    on QueryBuilder<EngagementEvent, EngagementEvent, QQueryProperty> {
  QueryBuilder<EngagementEvent, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<EngagementEvent, DateTime, QQueryOperations> atProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'at');
    });
  }

  QueryBuilder<EngagementEvent, String?, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<EngagementEvent, String?, QQueryOperations>
      clusterLabelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clusterLabel');
    });
  }

  QueryBuilder<EngagementEvent, int, QQueryOperations> hourLocalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hourLocal');
    });
  }

  QueryBuilder<EngagementEvent, String?, QQueryOperations> queryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'query');
    });
  }

  QueryBuilder<EngagementEvent, String?, QQueryOperations> sourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'source');
    });
  }

  QueryBuilder<EngagementEvent, String?, QQueryOperations>
      triggerTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'triggerType');
    });
  }

  QueryBuilder<EngagementEvent, EngagementEventType, QQueryOperations>
      typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }

  QueryBuilder<EngagementEvent, int?, QQueryOperations> urlIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'urlId');
    });
  }
}
