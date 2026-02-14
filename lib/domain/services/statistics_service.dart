import 'dart:math' as math;

import '../../core/identity.dart';
import '../entities/location_point.dart';
import '../entities/meeting_proof.dart';

class UserStats {
  const UserStats({
    required this.meetingsCount,
    required this.totalDistanceKm,
    required this.uniquePeopleCount,
    required this.streakDays,
  });

  final int meetingsCount;
  final double totalDistanceKm;
  final int uniquePeopleCount;
  final int streakDays;
}

class StatisticsService {
  UserStats buildStats(
    List<MeetingProof> proofs, {
    required Ed25519Identity me,
  }) {
    return UserStats(
      meetingsCount: proofs.length,
      totalDistanceKm: calculateTotalDistance(proofs),
      uniquePeopleCount: countUniquePeople(proofs, me),
      streakDays: calculateStreak(proofs),
    );
  }

  double calculateTotalDistance(List<MeetingProof> proofs) {
    if (proofs.length < 2) {
      return 0.0;
    }

    final sorted = [...proofs]..sort(_compareByTimestampAsc);

    var totalDistance = 0.0;
    LocationPoint? previous;
    for (final proof in sorted) {
      final current = proof.location;
      if (_isZeroCoordinate(current)) {
        // (0,0) is treated as "no movement / unknown location".
        previous = null;
        continue;
      }

      if (previous != null) {
        totalDistance += _haversineDistanceKm(previous, current);
      }
      previous = current;
    }

    return totalDistance;
  }

  int countUniquePeople(List<MeetingProof> proofs, Ed25519Identity me) {
    final meKey = me.publicKeyHex.toLowerCase();
    final uniqueKeys = <String>{};

    for (final proof in proofs) {
      for (final signature in proof.signatures) {
        final key = signature.publicKeyHex.trim().toLowerCase();
        if (key.isEmpty || key == meKey) {
          continue;
        }
        uniqueKeys.add(key);
      }
    }

    return uniqueKeys.length;
  }

  int calculateStreak(List<MeetingProof> proofs) {
    if (proofs.isEmpty) {
      return 0;
    }

    final uniqueDays = proofs
        .map((proof) => DateTime.tryParse(proof.timestamp)?.toUtc())
        .whereType<DateTime>()
        .map((timestamp) => DateTime.utc(
              timestamp.year,
              timestamp.month,
              timestamp.day,
            ))
        .toSet()
        .toList()
      ..sort();

    if (uniqueDays.isEmpty) {
      return 0;
    }

    var longest = 1;
    var current = 1;
    for (var i = 1; i < uniqueDays.length; i++) {
      final deltaDays = uniqueDays[i].difference(uniqueDays[i - 1]).inDays;
      if (deltaDays == 1) {
        current++;
      } else if (deltaDays > 1) {
        current = 1;
      }
      if (current > longest) {
        longest = current;
      }
    }

    return longest;
  }

  int _compareByTimestampAsc(MeetingProof a, MeetingProof b) {
    final at = DateTime.tryParse(a.timestamp);
    final bt = DateTime.tryParse(b.timestamp);
    if (at == null && bt == null) {
      return a.timestamp.compareTo(b.timestamp);
    }
    if (at == null) {
      return 1;
    }
    if (bt == null) {
      return -1;
    }
    return at.compareTo(bt);
  }

  bool _isZeroCoordinate(LocationPoint point) {
    return point.latitude == 0.0 && point.longitude == 0.0;
  }

  double _haversineDistanceKm(LocationPoint a, LocationPoint b) {
    const earthRadiusKm = 6371.0;
    final lat1 = _toRadians(a.latitude);
    final lon1 = _toRadians(a.longitude);
    final lat2 = _toRadians(b.latitude);
    final lon2 = _toRadians(b.longitude);

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final haversine = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.sqrt(haversine));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);
}
