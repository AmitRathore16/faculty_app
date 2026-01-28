class AppLinksConfig {
  static const String vercelBaseUrl = "https://faculty-pedia-links.vercel.app";

  // Educator profile route
  static String educatorProfile(String educatorId) {
    return "$vercelBaseUrl/educator/$educatorId";
  }
  static String webinarDetails(String webinarId) {
    return "$vercelBaseUrl/webinar/$webinarId";
  }
  static String testSeriesDetails(String testSeriesId) {
    return "$vercelBaseUrl/test-series/$testSeriesId";
  }
  static String courseDetails(String courseId) {
    return "$vercelBaseUrl/course/$courseId";
  }

}
