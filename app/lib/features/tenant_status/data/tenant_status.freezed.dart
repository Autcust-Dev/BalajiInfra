// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tenant_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TenantStatus {

 bool get hasConsent; KycStatus get kycStatus;
/// Create a copy of TenantStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TenantStatusCopyWith<TenantStatus> get copyWith => _$TenantStatusCopyWithImpl<TenantStatus>(this as TenantStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TenantStatus&&(identical(other.hasConsent, hasConsent) || other.hasConsent == hasConsent)&&(identical(other.kycStatus, kycStatus) || other.kycStatus == kycStatus));
}


@override
int get hashCode => Object.hash(runtimeType,hasConsent,kycStatus);

@override
String toString() {
  return 'TenantStatus(hasConsent: $hasConsent, kycStatus: $kycStatus)';
}


}

/// @nodoc
abstract mixin class $TenantStatusCopyWith<$Res>  {
  factory $TenantStatusCopyWith(TenantStatus value, $Res Function(TenantStatus) _then) = _$TenantStatusCopyWithImpl;
@useResult
$Res call({
 bool hasConsent, KycStatus kycStatus
});




}
/// @nodoc
class _$TenantStatusCopyWithImpl<$Res>
    implements $TenantStatusCopyWith<$Res> {
  _$TenantStatusCopyWithImpl(this._self, this._then);

  final TenantStatus _self;
  final $Res Function(TenantStatus) _then;

/// Create a copy of TenantStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasConsent = null,Object? kycStatus = null,}) {
  return _then(_self.copyWith(
hasConsent: null == hasConsent ? _self.hasConsent : hasConsent // ignore: cast_nullable_to_non_nullable
as bool,kycStatus: null == kycStatus ? _self.kycStatus : kycStatus // ignore: cast_nullable_to_non_nullable
as KycStatus,
  ));
}

}


/// Adds pattern-matching-related methods to [TenantStatus].
extension TenantStatusPatterns on TenantStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TenantStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TenantStatus() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TenantStatus value)  $default,){
final _that = this;
switch (_that) {
case _TenantStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TenantStatus value)?  $default,){
final _that = this;
switch (_that) {
case _TenantStatus() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hasConsent,  KycStatus kycStatus)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TenantStatus() when $default != null:
return $default(_that.hasConsent,_that.kycStatus);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hasConsent,  KycStatus kycStatus)  $default,) {final _that = this;
switch (_that) {
case _TenantStatus():
return $default(_that.hasConsent,_that.kycStatus);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hasConsent,  KycStatus kycStatus)?  $default,) {final _that = this;
switch (_that) {
case _TenantStatus() when $default != null:
return $default(_that.hasConsent,_that.kycStatus);case _:
  return null;

}
}

}

/// @nodoc


class _TenantStatus implements TenantStatus {
  const _TenantStatus({required this.hasConsent, required this.kycStatus});
  

@override final  bool hasConsent;
@override final  KycStatus kycStatus;

/// Create a copy of TenantStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TenantStatusCopyWith<_TenantStatus> get copyWith => __$TenantStatusCopyWithImpl<_TenantStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TenantStatus&&(identical(other.hasConsent, hasConsent) || other.hasConsent == hasConsent)&&(identical(other.kycStatus, kycStatus) || other.kycStatus == kycStatus));
}


@override
int get hashCode => Object.hash(runtimeType,hasConsent,kycStatus);

@override
String toString() {
  return 'TenantStatus(hasConsent: $hasConsent, kycStatus: $kycStatus)';
}


}

/// @nodoc
abstract mixin class _$TenantStatusCopyWith<$Res> implements $TenantStatusCopyWith<$Res> {
  factory _$TenantStatusCopyWith(_TenantStatus value, $Res Function(_TenantStatus) _then) = __$TenantStatusCopyWithImpl;
@override @useResult
$Res call({
 bool hasConsent, KycStatus kycStatus
});




}
/// @nodoc
class __$TenantStatusCopyWithImpl<$Res>
    implements _$TenantStatusCopyWith<$Res> {
  __$TenantStatusCopyWithImpl(this._self, this._then);

  final _TenantStatus _self;
  final $Res Function(_TenantStatus) _then;

/// Create a copy of TenantStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasConsent = null,Object? kycStatus = null,}) {
  return _then(_TenantStatus(
hasConsent: null == hasConsent ? _self.hasConsent : hasConsent // ignore: cast_nullable_to_non_nullable
as bool,kycStatus: null == kycStatus ? _self.kycStatus : kycStatus // ignore: cast_nullable_to_non_nullable
as KycStatus,
  ));
}


}

// dart format on
