// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meeting_proof_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMeetingProofModelCollection on Isar {
  IsarCollection<MeetingProofModel> get meetingProofModels => this.collection();
}

const MeetingProofModelSchema = CollectionSchema(
  name: r'MeetingProofModel',
  id: -3755529693830975953,
  properties: {
    r'latitude': PropertySchema(
      id: 0,
      name: r'latitude',
      type: IsarType.double,
    ),
    r'longitude': PropertySchema(
      id: 1,
      name: r'longitude',
      type: IsarType.double,
    ),
    r'previousMeetingHash': PropertySchema(
      id: 2,
      name: r'previousMeetingHash',
      type: IsarType.string,
    ),
    r'proofHash': PropertySchema(
      id: 3,
      name: r'proofHash',
      type: IsarType.string,
    ),
    r'saltedVectorHash': PropertySchema(
      id: 4,
      name: r'saltedVectorHash',
      type: IsarType.string,
    ),
    r'signaturesJson': PropertySchema(
      id: 5,
      name: r'signaturesJson',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 6,
      name: r'timestamp',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _meetingProofModelEstimateSize,
  serialize: _meetingProofModelSerialize,
  deserialize: _meetingProofModelDeserialize,
  deserializeProp: _meetingProofModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'proofHash': IndexSchema(
      id: -4422655257397861356,
      name: r'proofHash',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'proofHash',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _meetingProofModelGetId,
  getLinks: _meetingProofModelGetLinks,
  attach: _meetingProofModelAttach,
  version: '3.1.0+1',
);

int _meetingProofModelEstimateSize(
  MeetingProofModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.previousMeetingHash.length * 3;
  bytesCount += 3 + object.proofHash.length * 3;
  bytesCount += 3 + object.saltedVectorHash.length * 3;
  bytesCount += 3 + object.signaturesJson.length * 3;
  return bytesCount;
}

void _meetingProofModelSerialize(
  MeetingProofModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.latitude);
  writer.writeDouble(offsets[1], object.longitude);
  writer.writeString(offsets[2], object.previousMeetingHash);
  writer.writeString(offsets[3], object.proofHash);
  writer.writeString(offsets[4], object.saltedVectorHash);
  writer.writeString(offsets[5], object.signaturesJson);
  writer.writeDateTime(offsets[6], object.timestamp);
}

MeetingProofModel _meetingProofModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MeetingProofModel();
  object.id = id;
  object.latitude = reader.readDouble(offsets[0]);
  object.longitude = reader.readDouble(offsets[1]);
  object.previousMeetingHash = reader.readString(offsets[2]);
  object.proofHash = reader.readString(offsets[3]);
  object.saltedVectorHash = reader.readString(offsets[4]);
  object.signaturesJson = reader.readString(offsets[5]);
  object.timestamp = reader.readDateTime(offsets[6]);
  return object;
}

P _meetingProofModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _meetingProofModelGetId(MeetingProofModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _meetingProofModelGetLinks(
    MeetingProofModel object) {
  return [];
}

void _meetingProofModelAttach(
    IsarCollection<dynamic> col, Id id, MeetingProofModel object) {
  object.id = id;
}

extension MeetingProofModelByIndex on IsarCollection<MeetingProofModel> {
  Future<MeetingProofModel?> getByProofHash(String proofHash) {
    return getByIndex(r'proofHash', [proofHash]);
  }

  MeetingProofModel? getByProofHashSync(String proofHash) {
    return getByIndexSync(r'proofHash', [proofHash]);
  }

  Future<bool> deleteByProofHash(String proofHash) {
    return deleteByIndex(r'proofHash', [proofHash]);
  }

  bool deleteByProofHashSync(String proofHash) {
    return deleteByIndexSync(r'proofHash', [proofHash]);
  }

  Future<List<MeetingProofModel?>> getAllByProofHash(
      List<String> proofHashValues) {
    final values = proofHashValues.map((e) => [e]).toList();
    return getAllByIndex(r'proofHash', values);
  }

  List<MeetingProofModel?> getAllByProofHashSync(List<String> proofHashValues) {
    final values = proofHashValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'proofHash', values);
  }

  Future<int> deleteAllByProofHash(List<String> proofHashValues) {
    final values = proofHashValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'proofHash', values);
  }

  int deleteAllByProofHashSync(List<String> proofHashValues) {
    final values = proofHashValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'proofHash', values);
  }

  Future<Id> putByProofHash(MeetingProofModel object) {
    return putByIndex(r'proofHash', object);
  }

  Id putByProofHashSync(MeetingProofModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'proofHash', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByProofHash(List<MeetingProofModel> objects) {
    return putAllByIndex(r'proofHash', objects);
  }

  List<Id> putAllByProofHashSync(List<MeetingProofModel> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'proofHash', objects, saveLinks: saveLinks);
  }
}

extension MeetingProofModelQueryWhereSort
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QWhere> {
  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension MeetingProofModelQueryWhere
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QWhereClause> {
  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
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

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
      proofHashEqualTo(String proofHash) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'proofHash',
        value: [proofHash],
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterWhereClause>
      proofHashNotEqualTo(String proofHash) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'proofHash',
              lower: [],
              upper: [proofHash],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'proofHash',
              lower: [proofHash],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'proofHash',
              lower: [proofHash],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'proofHash',
              lower: [],
              upper: [proofHash],
              includeUpper: false,
            ));
      }
    });
  }
}

extension MeetingProofModelQueryFilter
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QFilterCondition> {
  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
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

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
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

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
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

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      latitudeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'latitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      latitudeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'latitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      latitudeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'latitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      latitudeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'latitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      longitudeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      longitudeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      longitudeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longitude',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      longitudeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longitude',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'previousMeetingHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'previousMeetingHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'previousMeetingHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'previousMeetingHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'previousMeetingHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'previousMeetingHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'previousMeetingHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'previousMeetingHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'previousMeetingHash',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      previousMeetingHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'previousMeetingHash',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'proofHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'proofHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'proofHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'proofHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'proofHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'proofHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'proofHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'proofHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'proofHash',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      proofHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'proofHash',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'saltedVectorHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'saltedVectorHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'saltedVectorHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'saltedVectorHash',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'saltedVectorHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'saltedVectorHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'saltedVectorHash',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'saltedVectorHash',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'saltedVectorHash',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      saltedVectorHashIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'saltedVectorHash',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signaturesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'signaturesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'signaturesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'signaturesJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'signaturesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'signaturesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'signaturesJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'signaturesJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'signaturesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      signaturesJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'signaturesJson',
        value: '',
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MeetingProofModelQueryObject
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QFilterCondition> {}

extension MeetingProofModelQueryLinks
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QFilterCondition> {}

extension MeetingProofModelQuerySortBy
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QSortBy> {
  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByPreviousMeetingHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousMeetingHash', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByPreviousMeetingHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousMeetingHash', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByProofHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proofHash', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByProofHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proofHash', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortBySaltedVectorHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saltedVectorHash', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortBySaltedVectorHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saltedVectorHash', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortBySignaturesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signaturesJson', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortBySignaturesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signaturesJson', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension MeetingProofModelQuerySortThenBy
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QSortThenBy> {
  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByLatitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'latitude', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByLongitudeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longitude', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByPreviousMeetingHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousMeetingHash', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByPreviousMeetingHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'previousMeetingHash', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByProofHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proofHash', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByProofHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'proofHash', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenBySaltedVectorHash() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saltedVectorHash', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenBySaltedVectorHashDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'saltedVectorHash', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenBySignaturesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signaturesJson', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenBySignaturesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'signaturesJson', Sort.desc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension MeetingProofModelQueryWhereDistinct
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct> {
  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctByLatitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'latitude');
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctByLongitude() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longitude');
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctByPreviousMeetingHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'previousMeetingHash',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctByProofHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'proofHash', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctBySaltedVectorHash({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'saltedVectorHash',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctBySignaturesJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'signaturesJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MeetingProofModel, MeetingProofModel, QDistinct>
      distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension MeetingProofModelQueryProperty
    on QueryBuilder<MeetingProofModel, MeetingProofModel, QQueryProperty> {
  QueryBuilder<MeetingProofModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MeetingProofModel, double, QQueryOperations> latitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'latitude');
    });
  }

  QueryBuilder<MeetingProofModel, double, QQueryOperations>
      longitudeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longitude');
    });
  }

  QueryBuilder<MeetingProofModel, String, QQueryOperations>
      previousMeetingHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'previousMeetingHash');
    });
  }

  QueryBuilder<MeetingProofModel, String, QQueryOperations>
      proofHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'proofHash');
    });
  }

  QueryBuilder<MeetingProofModel, String, QQueryOperations>
      saltedVectorHashProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'saltedVectorHash');
    });
  }

  QueryBuilder<MeetingProofModel, String, QQueryOperations>
      signaturesJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'signaturesJson');
    });
  }

  QueryBuilder<MeetingProofModel, DateTime, QQueryOperations>
      timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
