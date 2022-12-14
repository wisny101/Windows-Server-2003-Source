//
// Normally when you make a change you change the 3rd digit in the version number,
// ie, COMPATADMIN_BIN_VERSION_DIGIT3 unless you are making major changes.
//
// Example: changing from 3.0.88.0 to 3.0.89.0
//

#define COMPATADMIN_BIN_VERSION_DIGIT1 3
#define COMPATADMIN_BIN_VERSION_DIGIT2 0

//
// Increase me when you update the code unless you are making major changes!
//
#define COMPATADMIN_BIN_VERSION_DIGIT3 96

#define COMPATADMIN_BIN_VERSION_DIGIT4 0

#define COMPATADMIN_BIN_VERSION COMPATADMIN_BIN_VERSION_DIGIT1,COMPATADMIN_BIN_VERSION_DIGIT2,COMPATADMIN_BIN_VERSION_DIGIT3,COMPATADMIN_BIN_VERSION_DIGIT4
#define COMPATADMIN_STRING_VERSION_HELPER(x) #x
#define COMPATADMIN_STRING_VERSION(x) COMPATADMIN_STRING_VERSION_HELPER(x)

#define COMPATADMIN_BIN_VERSION_HELP COMPATADMIN_BIN_VERSION_DIGIT1.COMPATADMIN_BIN_VERSION_DIGIT2.COMPATADMIN_BIN_VERSION_DIGIT3
