#ifndef HELPER_HPP
#define HELPER_HPP

/* Pointer guard, which copies the instance on each copy.
 * Useful to mark optional data.
 */
template< typename T >
struct CopyPtr {
	T *ptr;

	CopyPtr() : ptr(nullptr) { }
	CopyPtr(T *ptr) : ptr(ptr) { }
	CopyPtr(const T &t) : ptr(new T(t)) { }
	CopyPtr(const CopyPtr<T> &other) {
		this->ptr = nullptr;
		if (other.ptr) {
			this->ptr = new T(*other.ptr);
		}
	}

	const T *operator=(const T *other) {
		delete this->ptr;
		this->ptr = new T(*other);
		return other;
	}

	T *operator=(T *other) {
		delete this->ptr;
		this->ptr = other;
		return other;
	}

	const T &operator=(const T &other) {
		delete this->ptr;
		this->ptr = new T(other);
		return other;
	}

	operator bool() const {
		return this->ptr != nullptr;
	}

	CopyPtr<T> &operator=(CopyPtr<T> &&other) {
		delete this->ptr;
		this->ptr = other.ptr;
		other.ptr = nullptr;
		return *this;
	}

	~CopyPtr() {
		delete this->ptr;
	}

	T *operator->() { return this->ptr; }
	const T *operator->() const { return this->ptr; }

	T &operator*() { return *this->ptr; }
	const T &operator*() const { return *this->ptr; }
};

#endif // HELPER_HPP
