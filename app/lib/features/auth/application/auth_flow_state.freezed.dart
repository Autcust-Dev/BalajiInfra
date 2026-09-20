// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_flow_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthFlowState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthFlowState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState()';
}


}

/// @nodoc
class $AuthFlowStateCopyWith<$Res>  {
$AuthFlowStateCopyWith(AuthFlowState _, $Res Function(AuthFlowState) __);
}


/// Adds pattern-matching-related methods to [AuthFlowState].
extension AuthFlowStatePatterns on AuthFlowState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _EnteringPhone value)?  enteringPhone,TResult Function( _CheckingPhone value)?  checkingPhone,TResult Function( _NotAllowed value)?  notAllowed,TResult Function( _OtpSent value)?  otpSent,TResult Function( _VerifyingOtp value)?  verifyingOtp,TResult Function( _LinkingTenant value)?  linkingTenant,TResult Function( _SignedIn value)?  signedIn,TResult Function( _Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EnteringPhone() when enteringPhone != null:
return enteringPhone(_that);case _CheckingPhone() when checkingPhone != null:
return checkingPhone(_that);case _NotAllowed() when notAllowed != null:
return notAllowed(_that);case _OtpSent() when otpSent != null:
return otpSent(_that);case _VerifyingOtp() when verifyingOtp != null:
return verifyingOtp(_that);case _LinkingTenant() when linkingTenant != null:
return linkingTenant(_that);case _SignedIn() when signedIn != null:
return signedIn(_that);case _Error() when error != null:
return error(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _EnteringPhone value)  enteringPhone,required TResult Function( _CheckingPhone value)  checkingPhone,required TResult Function( _NotAllowed value)  notAllowed,required TResult Function( _OtpSent value)  otpSent,required TResult Function( _VerifyingOtp value)  verifyingOtp,required TResult Function( _LinkingTenant value)  linkingTenant,required TResult Function( _SignedIn value)  signedIn,required TResult Function( _Error value)  error,}){
final _that = this;
switch (_that) {
case _EnteringPhone():
return enteringPhone(_that);case _CheckingPhone():
return checkingPhone(_that);case _NotAllowed():
return notAllowed(_that);case _OtpSent():
return otpSent(_that);case _VerifyingOtp():
return verifyingOtp(_that);case _LinkingTenant():
return linkingTenant(_that);case _SignedIn():
return signedIn(_that);case _Error():
return error(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _EnteringPhone value)?  enteringPhone,TResult? Function( _CheckingPhone value)?  checkingPhone,TResult? Function( _NotAllowed value)?  notAllowed,TResult? Function( _OtpSent value)?  otpSent,TResult? Function( _VerifyingOtp value)?  verifyingOtp,TResult? Function( _LinkingTenant value)?  linkingTenant,TResult? Function( _SignedIn value)?  signedIn,TResult? Function( _Error value)?  error,}){
final _that = this;
switch (_that) {
case _EnteringPhone() when enteringPhone != null:
return enteringPhone(_that);case _CheckingPhone() when checkingPhone != null:
return checkingPhone(_that);case _NotAllowed() when notAllowed != null:
return notAllowed(_that);case _OtpSent() when otpSent != null:
return otpSent(_that);case _VerifyingOtp() when verifyingOtp != null:
return verifyingOtp(_that);case _LinkingTenant() when linkingTenant != null:
return linkingTenant(_that);case _SignedIn() when signedIn != null:
return signedIn(_that);case _Error() when error != null:
return error(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  enteringPhone,TResult Function()?  checkingPhone,TResult Function()?  notAllowed,TResult Function( String verificationId,  String phone)?  otpSent,TResult Function()?  verifyingOtp,TResult Function()?  linkingTenant,TResult Function()?  signedIn,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EnteringPhone() when enteringPhone != null:
return enteringPhone();case _CheckingPhone() when checkingPhone != null:
return checkingPhone();case _NotAllowed() when notAllowed != null:
return notAllowed();case _OtpSent() when otpSent != null:
return otpSent(_that.verificationId,_that.phone);case _VerifyingOtp() when verifyingOtp != null:
return verifyingOtp();case _LinkingTenant() when linkingTenant != null:
return linkingTenant();case _SignedIn() when signedIn != null:
return signedIn();case _Error() when error != null:
return error(_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  enteringPhone,required TResult Function()  checkingPhone,required TResult Function()  notAllowed,required TResult Function( String verificationId,  String phone)  otpSent,required TResult Function()  verifyingOtp,required TResult Function()  linkingTenant,required TResult Function()  signedIn,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case _EnteringPhone():
return enteringPhone();case _CheckingPhone():
return checkingPhone();case _NotAllowed():
return notAllowed();case _OtpSent():
return otpSent(_that.verificationId,_that.phone);case _VerifyingOtp():
return verifyingOtp();case _LinkingTenant():
return linkingTenant();case _SignedIn():
return signedIn();case _Error():
return error(_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  enteringPhone,TResult? Function()?  checkingPhone,TResult? Function()?  notAllowed,TResult? Function( String verificationId,  String phone)?  otpSent,TResult? Function()?  verifyingOtp,TResult? Function()?  linkingTenant,TResult? Function()?  signedIn,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case _EnteringPhone() when enteringPhone != null:
return enteringPhone();case _CheckingPhone() when checkingPhone != null:
return checkingPhone();case _NotAllowed() when notAllowed != null:
return notAllowed();case _OtpSent() when otpSent != null:
return otpSent(_that.verificationId,_that.phone);case _VerifyingOtp() when verifyingOtp != null:
return verifyingOtp();case _LinkingTenant() when linkingTenant != null:
return linkingTenant();case _SignedIn() when signedIn != null:
return signedIn();case _Error() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _EnteringPhone implements AuthFlowState {
  const _EnteringPhone();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EnteringPhone);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState.enteringPhone()';
}


}




/// @nodoc


class _CheckingPhone implements AuthFlowState {
  const _CheckingPhone();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CheckingPhone);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState.checkingPhone()';
}


}




/// @nodoc


class _NotAllowed implements AuthFlowState {
  const _NotAllowed();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotAllowed);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState.notAllowed()';
}


}




/// @nodoc


class _OtpSent implements AuthFlowState {
  const _OtpSent(this.verificationId, this.phone);
  

 final  String verificationId;
 final  String phone;

/// Create a copy of AuthFlowState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OtpSentCopyWith<_OtpSent> get copyWith => __$OtpSentCopyWithImpl<_OtpSent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OtpSent&&(identical(other.verificationId, verificationId) || other.verificationId == verificationId)&&(identical(other.phone, phone) || other.phone == phone));
}


@override
int get hashCode => Object.hash(runtimeType,verificationId,phone);

@override
String toString() {
  return 'AuthFlowState.otpSent(verificationId: $verificationId, phone: $phone)';
}


}

/// @nodoc
abstract mixin class _$OtpSentCopyWith<$Res> implements $AuthFlowStateCopyWith<$Res> {
  factory _$OtpSentCopyWith(_OtpSent value, $Res Function(_OtpSent) _then) = __$OtpSentCopyWithImpl;
@useResult
$Res call({
 String verificationId, String phone
});




}
/// @nodoc
class __$OtpSentCopyWithImpl<$Res>
    implements _$OtpSentCopyWith<$Res> {
  __$OtpSentCopyWithImpl(this._self, this._then);

  final _OtpSent _self;
  final $Res Function(_OtpSent) _then;

/// Create a copy of AuthFlowState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? verificationId = null,Object? phone = null,}) {
  return _then(_OtpSent(
null == verificationId ? _self.verificationId : verificationId // ignore: cast_nullable_to_non_nullable
as String,null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class _VerifyingOtp implements AuthFlowState {
  const _VerifyingOtp();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyingOtp);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState.verifyingOtp()';
}


}




/// @nodoc


class _LinkingTenant implements AuthFlowState {
  const _LinkingTenant();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LinkingTenant);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState.linkingTenant()';
}


}




/// @nodoc


class _SignedIn implements AuthFlowState {
  const _SignedIn();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SignedIn);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'AuthFlowState.signedIn()';
}


}




/// @nodoc


class _Error implements AuthFlowState {
  const _Error(this.message);
  

 final  String message;

/// Create a copy of AuthFlowState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ErrorCopyWith<_Error> get copyWith => __$ErrorCopyWithImpl<_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Error&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'AuthFlowState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res> implements $AuthFlowStateCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) = __$ErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class __$ErrorCopyWithImpl<$Res>
    implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

/// Create a copy of AuthFlowState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(_Error(
null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
