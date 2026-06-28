class IAPIds {
  static const String noAdsDay   = 'remove_ads_day';
  static const String noAdsWeek  = 'remove_ads_weekend';
  static const String noAdsMonth = 'remove_ads_month';

  static const Set<String> all = {
    noAdsDay,
    noAdsWeek,
    noAdsMonth,
  };

  static const Map<String, Duration> durations = {
    noAdsDay:   Duration(days: 1),
    noAdsWeek:  Duration(days: 2),
    noAdsMonth: Duration(days: 30),
  };
}
