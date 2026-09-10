// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glimpse_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetGlimpseRecordCollection on Isar {
  IsarCollection<GlimpseRecord> get glimpseRecords => this.collection();
}

const GlimpseRecordSchema = CollectionSchema(
  name: r'GlimpseRecord',
  id: -1585228343602810302,
  properties: {
    r'contentJson': PropertySchema(
      id: 0,
      name: r'contentJson',
      type: IsarType.string,
    ),
    r'deliveryLeaseUntil': PropertySchema(
      id: 1,
      name: r'deliveryLeaseUntil',
      type: IsarType.dateTime,
    ),
    r'key': PropertySchema(
      id: 2,
      name: r'key',
      type: IsarType.string,
    ),
    r'openedAt': PropertySchema(
      id: 3,
      name: r'openedAt',
      type: IsarType.dateTime,
    ),
    r'postedAt': PropertySchema(
      id: 4,
      name: r'postedAt',
      type: IsarType.dateTime,
    ),
    r'reminderPostedAt': PropertySchema(
      id: 5,
      name: r'reminderPostedAt',
      type: IsarType.dateTime,
    ),
    r'retiredAt': PropertySchema(
      id: 6,
      name: r'retiredAt',
      type: IsarType.dateTime,
    ),
    r'snoozedUntil': PropertySchema(
      id: 7,
      name: r'snoozedUntil',
      type: IsarType.dateTime,
    ),
    r'synthesisJson': PropertySchema(
      id: 8,
      name: r'synthesisJson',
      type: IsarType.string,
    ),
    r'synthesisKey': PropertySchema(
      id: 9,
      name: r'synthesisKey',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 10,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _glimpseRecordEstimateSize,
  serialize: _glimpseRecordSerialize,
  deserialize: _glimpseRecordDeserialize,
  deserializeProp: _glimpseRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'key': IndexSchema(
      id: -4906094122524121629,
      name: r'key',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'key',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _glimpseRecordGetId,
  getLinks: _glimpseRecordGetLinks,
  attach: _glimpseRecordAttach,
  version: '3.1.0+1',
);

int _glimpseRecordEstimateSize(
  GlimpseRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.contentJson.length * 3;
  bytesCount += 3 + object.key.length * 3;
  {
    final value = object.synthesisJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.synthesisKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _glimpseRecordSerialize(
  GlimpseRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.contentJson);
  writer.writeDateTime(offsets[1], object.deliveryLeaseUntil);
  writer.writeString(offsets[2], object.key);
  writer.writeDateTime(offsets[3], object.openedAt);
  writer.writeDateTime(offsets[4], object.postedAt);
  writer.writeDateTime(offsets[5], object.reminderPostedAt);
  writer.writeDateTime(offsets[6], object.retiredAt);
  writer.writeDateTime(offsets[7], object.snoozedUntil);
  writer.writeString(offsets[8], object.synthesisJson);
  writer.writeString(offsets[9], object.synthesisKey);
  writer.writeDateTime(offsets[10], object.updatedAt);
}

GlimpseRecord _glimpseRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = GlimpseRecord();
  object.contentJson = reader.readString(offsets[0]);
  object.deliveryLeaseUntil = reader.readDateTimeOrNull(offsets[1]);
  object.id = id;
  object.key = reader.readString(offsets[2]);
  object.openedAt = reader.readDateTimeOrNull(offsets[3]);
  object.postedAt = reader.readDateTimeOrNull(offsets[4]);
  object.reminderPostedAt = reader.readDateTimeOrNull(offsets[5]);
  object.retiredAt = reader.readDateTimeOrNull(offsets[6]);
  object.snoozedUntil = reader.readDateTimeOrNull(offsets[7]);
  object.synthesisJson = reader.readStringOrNull(offsets[8]);
  object.synthesisKey = reader.readStringOrNull(offsets[9]);
  object.updatedAt = reader.readDateTime(offsets[10]);
  return object;
}

P _glimpseRecordDeserializeProp<P>(
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
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _glimpseRecordGetId(GlimpseRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _glimpseRecordGetLinks(GlimpseRecord object) {
  return [];
}

void _glimpseRecordAttach(
    IsarCollection<dynamic> col, Id id, GlimpseRecord object) {
  object.id = id;
}

extension GlimpseRecordByIndex on IsarCollection<GlimpseRecord> {
  Future<GlimpseRecord?> getByKey(String key) {
    return getByIndex(r'key', [key]);
  }

  GlimpseRecord? getByKeySync(String key) {
    return getByIndexSync(r'key', [key]);
  }

  Future<bool> deleteByKey(String key) {
    return deleteByIndex(r'key', [key]);
  }

  bool deleteByKeySync(String key) {
    return deleteByIndexSync(r'key', [key]);
  }

  Future<List<GlimpseRecord?>> getAllByKey(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return getAllByIndex(r'key', values);
  }

  List<GlimpseRecord?> getAllByKeySync(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'key', values);
  }

  Future<int> deleteAllByKey(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'key', values);
  }

  int deleteAllByKeySync(List<String> keyValues) {
    final values = keyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'key', values);
  }

  Future<Id> putByKey(GlimpseRecord object) {
    return putByIndex(r'key', object);
  }

  Id putByKeySync(GlimpseRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'key', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByKey(List<GlimpseRecord> objects) {
    return putAllByIndex(r'key', objects);
  }

  List<Id> putAllByKeySync(List<GlimpseRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'key', objects, saveLinks: saveLinks);
  }
}

extension GlimpseRecordQueryWhereSort
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QWhere> {
  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GlimpseRecordQueryWhere
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QWhereClause> {
  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> idNotEqualTo(
      Id id) {
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> idBetween(
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> keyEqualTo(
      String key) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'key',
        value: [key],
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterWhereClause> keyNotEqualTo(
      String key) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'key',
              lower: [],
              upper: [key],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'key',
              lower: [key],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'key',
              lower: [key],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'key',
              lower: [],
              upper: [key],
              includeUpper: false,
            ));
      }
    });
  }
}

extension GlimpseRecordQueryFilter
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QFilterCondition> {
  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentJson',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      contentJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentJson',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      deliveryLeaseUntilIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deliveryLeaseUntil',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      deliveryLeaseUntilIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deliveryLeaseUntil',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      deliveryLeaseUntilEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deliveryLeaseUntil',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      deliveryLeaseUntilGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deliveryLeaseUntil',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      deliveryLeaseUntilLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deliveryLeaseUntil',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      deliveryLeaseUntilBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deliveryLeaseUntil',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> idBetween(
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> keyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      keyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> keyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> keyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'key',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      keyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> keyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> keyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition> keyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'key',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'key',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'key',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      openedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'openedAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      openedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'openedAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      openedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'openedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      openedAtGreaterThan(
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      openedAtLessThan(
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      openedAtBetween(
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

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      postedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'postedAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      postedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'postedAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      postedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'postedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      postedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'postedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      postedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'postedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      postedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'postedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      reminderPostedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reminderPostedAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      reminderPostedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reminderPostedAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      reminderPostedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reminderPostedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      reminderPostedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reminderPostedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      reminderPostedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reminderPostedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      reminderPostedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reminderPostedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      retiredAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'retiredAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      retiredAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'retiredAt',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      retiredAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      retiredAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      retiredAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'retiredAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      retiredAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'retiredAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      snoozedUntilIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'snoozedUntil',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      snoozedUntilIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'snoozedUntil',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      snoozedUntilEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'snoozedUntil',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      snoozedUntilGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'snoozedUntil',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      snoozedUntilLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'snoozedUntil',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      snoozedUntilBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'snoozedUntil',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'synthesisJson',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'synthesisJson',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'synthesisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'synthesisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'synthesisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'synthesisJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'synthesisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'synthesisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'synthesisJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'synthesisJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'synthesisJson',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'synthesisJson',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'synthesisKey',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'synthesisKey',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'synthesisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'synthesisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'synthesisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'synthesisKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'synthesisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'synthesisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'synthesisKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'synthesisKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'synthesisKey',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      synthesisKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'synthesisKey',
        value: '',
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension GlimpseRecordQueryObject
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QFilterCondition> {}

extension GlimpseRecordQueryLinks
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QFilterCondition> {}

extension GlimpseRecordQuerySortBy
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QSortBy> {
  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByContentJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentJson', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByContentJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentJson', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByDeliveryLeaseUntil() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryLeaseUntil', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByDeliveryLeaseUntilDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryLeaseUntil', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByPostedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByPostedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postedAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByReminderPostedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPostedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByReminderPostedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPostedAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByRetiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortBySnoozedUntil() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snoozedUntil', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortBySnoozedUntilDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snoozedUntil', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortBySynthesisJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisJson', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortBySynthesisJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisJson', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortBySynthesisKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisKey', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortBySynthesisKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisKey', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension GlimpseRecordQuerySortThenBy
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QSortThenBy> {
  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByContentJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentJson', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByContentJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentJson', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByDeliveryLeaseUntil() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryLeaseUntil', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByDeliveryLeaseUntilDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deliveryLeaseUntil', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByOpenedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'openedAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByPostedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByPostedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'postedAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByReminderPostedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPostedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByReminderPostedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reminderPostedAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByRetiredAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'retiredAt', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenBySnoozedUntil() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snoozedUntil', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenBySnoozedUntilDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'snoozedUntil', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenBySynthesisJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisJson', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenBySynthesisJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisJson', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenBySynthesisKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisKey', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenBySynthesisKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'synthesisKey', Sort.desc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension GlimpseRecordQueryWhereDistinct
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> {
  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctByContentJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct>
      distinctByDeliveryLeaseUntil() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deliveryLeaseUntil');
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctByKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'key', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctByOpenedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'openedAt');
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctByPostedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'postedAt');
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct>
      distinctByReminderPostedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reminderPostedAt');
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctByRetiredAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'retiredAt');
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct>
      distinctBySnoozedUntil() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'snoozedUntil');
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctBySynthesisJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'synthesisJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctBySynthesisKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'synthesisKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GlimpseRecord, GlimpseRecord, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension GlimpseRecordQueryProperty
    on QueryBuilder<GlimpseRecord, GlimpseRecord, QQueryProperty> {
  QueryBuilder<GlimpseRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<GlimpseRecord, String, QQueryOperations> contentJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentJson');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime?, QQueryOperations>
      deliveryLeaseUntilProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deliveryLeaseUntil');
    });
  }

  QueryBuilder<GlimpseRecord, String, QQueryOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'key');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime?, QQueryOperations> openedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'openedAt');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime?, QQueryOperations> postedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'postedAt');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime?, QQueryOperations>
      reminderPostedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reminderPostedAt');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime?, QQueryOperations> retiredAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'retiredAt');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime?, QQueryOperations>
      snoozedUntilProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'snoozedUntil');
    });
  }

  QueryBuilder<GlimpseRecord, String?, QQueryOperations>
      synthesisJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synthesisJson');
    });
  }

  QueryBuilder<GlimpseRecord, String?, QQueryOperations>
      synthesisKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'synthesisKey');
    });
  }

  QueryBuilder<GlimpseRecord, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
