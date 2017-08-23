#ifndef JSON_STREAM_HPP
#define JSON_STREAM_HPP

#include "helper.hpp"

/* Simple stream writer for JSON data. */
class JsonStream {
public:
	enum Terminal {
		ObjectBegin, // "{"
		ObjectEnd, // "}"
		ArrayBegin, // "["
		ArrayEnd, // "]"
		Comma, // ", "
		Separator, // ": "
		Null, // null
	};

	JsonStream(std::ostream &out)
		: m_out(out)
	{
		//
	}

	// Any integer type
	template<typename T, class = typename std::enable_if<std::is_integral<T>::value>::type>
	JsonStream &operator<<(T value) {
		this->m_out << value;
		return *this;
	}

	JsonStream &operator<<(bool value) {
		if (value)
			this->m_out << "true";
		else
			this->m_out << "false";

		return *this;
	}

	JsonStream &operator<<(const char *value) {
		this->m_out << '"';

		while (*value) {
			printChar(*value);
			value++;
		}

		this->m_out << '"';
		return *this;
	}

	JsonStream &operator<<(const std::string &value) {
		this->m_out << '"';

		for (char c : value)
			printChar(c);

		this->m_out << '"';
		return *this;
	}

	template< typename T >
	JsonStream &operator<<(const std::vector<T> &vec) {
		bool first = true;
		*this << ArrayBegin;

		for (const T &v : vec) {
			if (!first) *this << Comma;
			*this << v;
			first = false;
		}

		*this << ArrayEnd;
		return *this;
	}

	template< typename U, typename V >
	JsonStream &operator<<(const std::pair<U, V> &pair) {
		return *this << pair.first << Separator << pair.second;
	}

	template< typename T >
	JsonStream &operator<<(const T *object) {
		if (object) {
			return *this << *object;
		} else {
			return *this << Null;
		}
	}

	template< typename T >
	JsonStream &operator<<(const CopyPtr<T> object) {
		return *this << object.ptr;
	}

	/* // Use once C++17 is enabled.
	template< typename ... Types >
	JsonStream &operator<<(const std::variant< Types ... > &variant) {
		std::visit([this](const auto &v){ *this << v; }, variant);
		return *this;
	}
	*/

	JsonStream &operator<<(Terminal terminal) {
		switch (terminal) {
			case ObjectBegin: this->m_out << "{"; break;
			case ObjectEnd: this->m_out << "}"; break;
			case ArrayBegin: this->m_out << "["; break;
			case ArrayEnd: this->m_out << "]"; break;
			case Comma: this->m_out << ", "; break;
			case Separator: this->m_out << ": "; break;
			case Null: this->m_out << "null"; break;
		}

		return *this;
	}

private:
	void printChar(char c) {
		switch (c) {
			case '\\': this->m_out << "\\\\"; break;
			case '"': this->m_out << "\\\""; break;
			case '\n': this->m_out << "\\n"; break;
			case '\t': this->m_out << "\\t"; break;
			default: this->m_out << c; break;
		}
	}

	std::ostream &m_out;
};

#endif // JSON_STREAM_HPP
