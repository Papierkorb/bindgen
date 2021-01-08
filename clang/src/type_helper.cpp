#include "type_helper.hpp"

# if __clang_major__ < 6
  #include "clang/Tooling/Core/QualTypeNames.h"
# else
  #include "clang/AST/QualTypeNames.h"
# endif

#include "clang/AST/Type.h"
#include "clang/AST/Decl.h"
#include "clang/AST/DeclTemplate.h"
#include "clang/AST/ExprCXX.h"

# if defined(__LLVM_VERSION_8)
  #include "clang_type_name_llvm_8.hpp"
# else
  #include "clang_type_name.hpp"
# endif

static CopyPtr<Template> handleTemplate(const clang::TemplateSpecializationType *tmpl, clang::ASTContext &ctx);
static bool tryReadStringConstructor(LiteralData &literal, const clang::CXXConstructExpr *expr);

Type TypeHelper::qualTypeToType(const clang::QualType &qt, clang::ASTContext &ctx) {
	Type type;
	qualTypeToType(type, qt, ctx);
	return type;
}

void TypeHelper::qualTypeToType(Type &target, const clang::QualType &qt, clang::ASTContext &ctx) {
	const auto *elab = llvm::dyn_cast<clang::ElaboratedType>(qt.getTypePtr());
	clang::QualType ut = elab ? elab->getNamedType() : qt;

	if (target.fullName.empty()) {
		target.fullName = ClangTypeName::getFullyQualifiedName(qt, ctx);
	}

	if (qt->isReferenceType() || qt->isPointerType()) {
		target.isReference = target.isReference || qt->isReferenceType();
		target.isMove = target.isMove || qt->isRValueReferenceType();
		target.pointer++;
		return qualTypeToType(target, qt->getPointeeType(), ctx); // Recurse
	}

	// Not a reference or pointer.
	target.isConst = qt.isConstQualified();
	target.isVoid = qt->isVoidType();
	target.isBuiltin = qt->isBuiltinType();
	target.baseName = ClangTypeName::getFullyQualifiedName(qt.getUnqualifiedType(), ctx);

	if (const auto *tmpl = llvm::dyn_cast<clang::TemplateSpecializationType>(ut.getTypePtr())) {
		target.templ = handleTemplate(tmpl, ctx);
		if (target.templ) {
			target.templ->fullName = target.baseName;
		}
	}
}

static CopyPtr<Template> handleTemplate(const clang::TemplateSpecializationType *tmpl, clang::ASTContext &ctx) {
	Template t;

	if (!tmpl) return CopyPtr<Template>();

	if (const clang::TemplateDecl *decl = tmpl->getTemplateName().getAsTemplateDecl()) {
		t.baseName = decl->getQualifiedNameAsString();
	}

	for (const clang::TemplateArgument &argument : tmpl->template_arguments()) {
		// Don't allow non-type template arguments yet.
		if (argument.getKind() != clang::TemplateArgument::Type)
			return CopyPtr<Template>();

		Type type = TypeHelper::qualTypeToType(argument.getAsType(), ctx);
		t.arguments.push_back(type);
	}

	return CopyPtr<Template>(t);
}

Argument TypeHelper::processFunctionParameter(const clang::ParmVarDecl *decl) {
	clang::ASTContext &ctx = decl->getASTContext();
	Argument arg;

	clang::QualType qt = decl->getType();
	qualTypeToType(arg, qt, ctx);
	arg.name = decl->getQualifiedNameAsString();
	arg.isVariadic = false;
	arg.hasDefault = decl->hasDefaultArg();
	arg.value.clear();

	// If the parameter has a default value, try to figure out this value.  Can
	// fail if e.g. the call has side-effects (Like calling another method).  Will
	// work for constant expressions though, like `true` or `3 + 5`.
	if (arg.hasDefault) {
		TypeHelper::readValue(arg.value, qt, ctx, decl->getDefaultArg());
	}

	return arg;
}

static bool describesStringClass(const clang::CXXConstructorDecl *ctorDecl) {
	std::string name = ctorDecl->getParent()->getQualifiedNameAsString();
	if (name == "std::__cxx11::basic_string" || name == "std::__1::basic_string") {
		return true;
	} else {
		return false;
	}
}

static bool stringLiteralFromExpression(LiteralData &literal, const clang::Expr *expr) {
	if (const clang::MaterializeTemporaryExpr *argExpr = llvm::dyn_cast<clang::MaterializeTemporaryExpr>(expr)) {
#if __clang_major__ >= 10
		return stringLiteralFromExpression(literal, argExpr->getSubExpr());
#else
		return stringLiteralFromExpression(literal, argExpr->GetTemporaryExpr());
#endif
	} else if (const clang::ExprWithCleanups *cleanupExpr = llvm::dyn_cast<clang::ExprWithCleanups>(expr)) {
		return stringLiteralFromExpression(literal, cleanupExpr->getSubExpr());
	} else if (const clang::CXXBindTemporaryExpr *bindExpr = llvm::dyn_cast<clang::CXXBindTemporaryExpr>(expr)) {
		return stringLiteralFromExpression(literal, bindExpr->getSubExpr());
	} else if (const clang::CastExpr *castExpr = llvm::dyn_cast<clang::CastExpr>(expr)) {
		return stringLiteralFromExpression(literal, castExpr->getSubExprAsWritten());
	} else if (const clang::CXXConstructExpr *ctorExpr = llvm::dyn_cast<clang::CXXConstructExpr>(expr)) {
		return tryReadStringConstructor(literal, ctorExpr);
	} else if (const clang::ParenExpr *parenExpr = llvm::dyn_cast<clang::ParenExpr>(expr)) {
		return stringLiteralFromExpression(literal, parenExpr->getSubExpr());
	} else if (const clang::StringLiteral *strExpr = llvm::dyn_cast<clang::StringLiteral>(expr)) {
		// We found it!
		literal = strExpr->getString().str();
		return true;
	} else { // Failed to destructure.
		return false;
	}
}

static bool tryReadStringConstructor(LiteralData &literal, const clang::CXXConstructExpr *expr) {
	if (!describesStringClass(expr->getConstructor())) {
		return false;
	}

	// The constructor call needs to have no (= empty) or a single argument.
	if (expr->getNumArgs() == 0) { // This is an empty string!
		literal = std::string();
		return true;
	} else if (expr->getNumArgs() == 1) {
		return stringLiteralFromExpression(literal, expr->getArg(0));
	} else { // No rules for more than one argument.
		return false;
	}
}

bool TypeHelper::valueFromApValue(LiteralData &value, const clang::APValue &apValue, const clang::QualType &qt) {
	if (qt->isPointerType()) {
		// For a pointer-type, just store if it was `nullptr` (== true).
		value = apValue.isNullPointer();
	} else if (qt->isBooleanType()) {
		value = apValue.getInt().getBoolValue();
	} else if (qt->isIntegerType()) {
		const llvm::APSInt &v = apValue.getInt();
		if (qt->isSignedIntegerType())
			value = v.getExtValue();
		else {
			value = v.getZExtValue();
			// FIXME: Perhaps we need to convert it to string because JSON does not support uint64?
			// Then translate it on the other end?
			// value = std::to_string(v.getZExtValue());
		}
	} else if (qt->isFloatingType()) {
		const llvm::APFloat &f = apValue.getFloat();
		if (&f.getSemantics() == &llvm::APFloat::IEEEsingle()) {
			value = static_cast<double>(f.convertToFloat());
		} else if (&f.getSemantics() == &llvm::APFloat::IEEEdouble()) {
			value = f.convertToDouble();
		} else {
			return false;
		}
	} else {
		return false;
	}

	return true;
}

bool TypeHelper::readValue(LiteralData &literal, const clang::QualType &qt,
  clang::ASTContext &ctx, const clang::Expr *expr) {
	clang::Expr::EvalResult result;

	if (!expr) return false; // Sanity check

	if (!expr->EvaluateAsRValue(result, ctx)) {
		// Failed to evaluate - Try to unpack this expression
		return stringLiteralFromExpression(literal, expr);
	}

	if (result.HasSideEffects || result.HasUndefinedBehavior) {
		return false; // Don't accept if there are side-effects or undefined behaviour.
	}

	if (qt->isPointerType() && qt->getPointeeType()->isCharType()) {
		return stringLiteralFromExpression(literal, expr);
	} else {
		return TypeHelper::valueFromApValue(literal, result.Val, qt);
	}
}

void TypeHelper::addFunctionParameters(const clang::FunctionDecl *func, Method &m) {
	for (unsigned i = 0; i < func->getNumParams(); i++) {
		Argument arg = TypeHelper::processFunctionParameter(func->parameters()[i]);

		if (arg.hasDefault && m.firstDefaultArgument < 0)
			m.firstDefaultArgument = i;

		m.arguments.push_back(arg);
	}

	if (func->isVariadic()) { // Support vararg functions
		Argument arg;
		arg.name = "...";
		arg.isVariadic = true;
		arg.hasDefault = false;
		m.arguments.push_back(arg);
	}
}
