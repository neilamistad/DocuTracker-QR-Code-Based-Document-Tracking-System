import 'package:bcrypt/bcrypt.dart';

String hashPassword(String password) {
  return BCrypt.hashpw(password, BCrypt.gensalt());
}

bool verifyPassword(String password, String hashedPassword) {
  return BCrypt.checkpw(password, hashedPassword);
}