// Aula API endpoint constants
// Base URL: https://www.aula.dk/api/v23/?method=namespace.methodName
class ApiEndpoints {
  static const String baseUrl = 'https://www.aula.dk/api/v23/';

  // Session
  static const String keepAlive = 'session.keepAlive';

  // Profiles
  static const String getProfilesByLogin = 'profiles.getProfilesByLogin';
  static const String getProfileContext = 'profiles.getProfileContext';

  // Posts (Wall)
  static const String getAllPosts = 'posts.getAllPosts';

  // Messaging
  static const String getThreads = 'messaging.getThreads';
  static const String getMessagesForThread = 'messaging.getMessagesForThread';
  static const String startNewThread = 'messaging.startNewThread';
  static const String reply = 'messaging.reply';
  static const String setLastReadMessage = 'messaging.setLastReadMessage';
  static const String deleteThread = 'messaging.deleteThread';

  // Search
  static const String findMessage = 'search.findMessage';
  static const String findRecipients = 'search.findRecipients';

  // Institutions
  static const String getInstitutions = 'institutions.getInstitutions';

  // Calendar
  static const String getEventsByProfileIds = 'calendar.getEventsByProfileIdsAndResourceIds';
}
