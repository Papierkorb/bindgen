// Allow these tests to run without a real Qt installation.  Provide mocks for
// those features we require.

#define signals public
#define Q_GADGET void qt_check_for_QGADGET_macro();

struct QMetaObject {
  struct Connection {
    // Do nothing.
  };
};

struct QObject {
  template< typename T, typename F >
  static QMetaObject::Connection connect(void *ptr, T func, F delegate) {
    delegate(); // Call back to Crystal

    return QMetaObject::Connection();
  }
};

// On to the actual test classes:

// Tests signal/slots connection wrapping
class SomeObject {
public:
  int normalMethod() { return 1; }

signals:
  void stuffHappened() {
    // Empty.
  }
};

// Tests Q_GADGET cleaning
class SomeGadget {
public:
  // The real Q_GADGET would do the `public:` switch itself.
  Q_GADGET
};
