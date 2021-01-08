#include <type_traits>

template< typename T >
struct BindgenTypeInfo {
  static const bool isDefaultConstructible = std::is_default_constructible<T>::value;
};
