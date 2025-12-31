# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (M6KVM, 2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the Daybo Logic nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Chleb::Utils::OSError::Mapper;
use strict;
use warnings;
use Moose;

=head1 NAME

Chleb::Utils::OSError::Mapper

=head1 DESCRIPTION

Map system errors to public HTTP errors

=cut

extends 'Chleb::Bible::Base';

use Errno;
use HTTP::Status 6.39 qw(:constants status_constant_name status_message);
use POSIX qw(strerror);
use Readonly;

Readonly my %MAPPINGS => (
	0			=> HTTP_OK,					# SUCCESS
	Errno::EOWNERDEAD	=> HTTP_INTERNAL_SERVER_ERROR,			# Owner died
	Errno::ENOTCONN		=> HTTP_BAD_GATEWAY,				# Transport endpoint is not connected
	Errno::EBADR		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid request descriptor
	Errno::EOVERFLOW	=> HTTP_UNPROCESSABLE_ENTITY,			# Value too large for defined data type
	Errno::ENOTNAM		=> HTTP_INTERNAL_SERVER_ERROR,			# Not a XENIX named type file
	Errno::EPFNOSUPPORT	=> HTTP_SERVICE_UNAVAILABLE,			# Protocol family not supported
	Errno::ENXIO		=> HTTP_SERVICE_UNAVAILABLE,			# No such device or address
	Errno::EDEADLOCK	=> HTTP_INTERNAL_SERVER_ERROR,			# Resource deadlock avoided
	Errno::EPROTO		=> HTTP_INTERNAL_SERVER_ERROR,			# Protocol error
	Errno::ENOANO		=> HTTP_INTERNAL_SERVER_ERROR,			# No anode
	Errno::EDOTDOT		=> HTTP_INTERNAL_SERVER_ERROR,			# RFS specific error
	Errno::ENOBUFS		=> HTTP_INSUFFICIENT_STORAGE,			# No buffer space available
	Errno::EILSEQ		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid or incomplete multibyte or wide character
	Errno::EINTR		=> HTTP_INTERNAL_SERVER_ERROR,			# Interrupted system call
	Errno::ELIBEXEC		=> HTTP_INTERNAL_SERVER_ERROR,			# Cannot exec a shared library directly
	Errno::ECONNRESET	=> HTTP_INTERNAL_SERVER_ERROR,			# Connection reset by peer
	Errno::EIO		=> HTTP_INSUFFICIENT_STORAGE,			# Input/output error
	Errno::ECONNREFUSED	=> HTTP_SERVICE_UNAVAILABLE,			# Connection refused
	Errno::ENOTRECOVERABLE	=> HTTP_INTERNAL_SERVER_ERROR,			# State not recoverable
	Errno::EXFULL		=> HTTP_INSUFFICIENT_STORAGE,			# Exchange full
	Errno::ECOMM		=> HTTP_INTERNAL_SERVER_ERROR,			# Communication error on send
	Errno::EISNAM		=> HTTP_INTERNAL_SERVER_ERROR,			# Is a named type file
	Errno::EL3RST		=> HTTP_INTERNAL_SERVER_ERROR,			# Level 3 reset
	Errno::ELIBBAD		=> HTTP_INTERNAL_SERVER_ERROR,			# Accessing a corrupted shared library
	Errno::ERFKILL		=> HTTP_INTERNAL_SERVER_ERROR,			# Operation not possible due to RF-kill
	Errno::EISDIR		=> HTTP_INTERNAL_SERVER_ERROR,			# Is a directory
	Errno::EWOULDBLOCK	=> HTTP_TOO_MANY_REQUESTS,			# Resource temporarily unavailable
	Errno::EHOSTUNREACH	=> HTTP_BAD_GATEWAY,				# No route to host
	Errno::ESHUTDOWN	=> HTTP_SERVICE_UNAVAILABLE,			# Cannot send after transport endpoint shutdown
	Errno::ENOTUNIQ		=> HTTP_INTERNAL_SERVER_ERROR,			# Name not unique on network
	Errno::ELNRNG		=> HTTP_INTERNAL_SERVER_ERROR,			# Link number out of range
	Errno::EPROTONOSUPPORT	=> HTTP_INTERNAL_SERVER_ERROR,			# Protocol not supported
	Errno::ENETDOWN		=> HTTP_SERVICE_UNAVAILABLE,			# Network is down
	Errno::EFAULT		=> HTTP_INTERNAL_SERVER_ERROR,			# Bad address
	Errno::ENOTDIR		=> HTTP_INTERNAL_SERVER_ERROR,			# Not a directory
	Errno::EINVAL		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid argument
	Errno::EEXIST		=> HTTP_CONFLICT,				# File exists
	Errno::EL2NSYNC		=> HTTP_INTERNAL_SERVER_ERROR,			# Level 2 not synchronized
	Errno::ENOTSUP		=> HTTP_INTERNAL_SERVER_ERROR,			# Operation not supported
	Errno::EADDRNOTAVAIL	=> HTTP_INTERNAL_SERVER_ERROR,			# Cannot assign requested address
	Errno::EPERM		=> HTTP_FORBIDDEN,				# Operation not permitted
	Errno::ELIBMAX		=> HTTP_INTERNAL_SERVER_ERROR,			# Attempting to link in too many shared libraries
	Errno::EMLINK		=> HTTP_INSUFFICIENT_STORAGE,			# Too many links
	Errno::EMEDIUMTYPE	=> HTTP_INSUFFICIENT_STORAGE,			# Wrong medium type
	Errno::ETIME		=> HTTP_REQUEST_TIMEOUT,			# Timer expired
	Errno::EBADE		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid exchange
	Errno::ENOTEMPTY	=> HTTP_INTERNAL_SERVER_ERROR,			# Directory not empty
	Errno::EMFILE		=> HTTP_INSUFFICIENT_STORAGE,			# Too many open files
	Errno::ENOTTY		=> HTTP_INTERNAL_SERVER_ERROR,			# Inappropriate ioctl for device
	Errno::EMULTIHOP	=> HTTP_INTERNAL_SERVER_ERROR,			# Multihop attempted
	Errno::ETXTBSY		=> HTTP_CONFLICT,				# Text file busy
	Errno::ESRMNT		=> HTTP_INTERNAL_SERVER_ERROR,			# Srmount error
	Errno::ENOPROTOOPT	=> HTTP_INTERNAL_SERVER_ERROR,			# Protocol not available
	Errno::EREMCHG		=> HTTP_BAD_GATEWAY,				# Remote address changed
	Errno::EHOSTDOWN	=> HTTP_BAD_GATEWAY,				# Host is down
	Errno::EPIPE		=> HTTP_INTERNAL_SERVER_ERROR,			# Broken pipe
	Errno::EUSERS		=> HTTP_TOO_MANY_REQUESTS,			# Too many users
	Errno::ERANGE		=> HTTP_RANGE_NOT_SATISFIABLE,			# Numerical result out of range
	Errno::EKEYEXPIRED	=> HTTP_UNAUTHORIZED,				# Key has expired
	Errno::ESTRPIPE		=> HTTP_INTERNAL_SERVER_ERROR,			# Streams pipe error
	Errno::ENOSTR		=> HTTP_INTERNAL_SERVER_ERROR,			# Device not a stream
	Errno::ENETRESET	=> HTTP_SERVICE_UNAVAILABLE,			# Network dropped connection on reset
	Errno::EADV		=> HTTP_INTERNAL_SERVER_ERROR,			# Advertise error
	Errno::EBADRQC		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid request code
	Errno::ESOCKTNOSUPPORT	=> HTTP_INTERNAL_SERVER_ERROR,			# Socket type not supported
	Errno::EKEYREJECTED	=> HTTP_UNAUTHORIZED,				# Key was rejected by service
	Errno::ENOMEM		=> HTTP_TOO_MANY_REQUESTS,			# Cannot allocate memory
	Errno::ENODATA		=> HTTP_NOT_FOUND,				# No data available
	Errno::ENOEXEC		=> HTTP_INTERNAL_SERVER_ERROR,			# Exec format error
	Errno::EKEYREVOKED	=> HTTP_UNAUTHORIZED,				# Key has been revoked
	Errno::EUCLEAN		=> HTTP_INTERNAL_SERVER_ERROR,			# Structure needs cleaning
	Errno::ENONET		=> HTTP_SERVICE_UNAVAILABLE,			# Machine is not on the network
	Errno::EBFONT		=> HTTP_INTERNAL_SERVER_ERROR,			# Bad font file format
	Errno::EISCONN		=> HTTP_INTERNAL_SERVER_ERROR,			# Transport endpoint is already connected
	Errno::ENOMEDIUM	=> HTTP_INSUFFICIENT_STORAGE,			# No medium found
	Errno::ECONNABORTED	=> HTTP_INTERNAL_SERVER_ERROR,			# Software caused connection abort
	Errno::ENOCSI		=> HTTP_INTERNAL_SERVER_ERROR,			# No CSI structure available
	Errno::EHWPOISON	=> HTTP_INTERNAL_SERVER_ERROR,			# Memory page has hardware error
	Errno::EREMOTE		=> HTTP_INTERNAL_SERVER_ERROR,			# Object is remote
	Errno::EINPROGRESS	=> HTTP_INTERNAL_SERVER_ERROR,			# Operation now in progress
	Errno::ETOOMANYREFS	=> HTTP_INTERNAL_SERVER_ERROR,			# Too many references: cannot splice
	Errno::EBADFD		=> HTTP_INTERNAL_SERVER_ERROR,			# File descriptor in bad state
	Errno::EBADF		=> HTTP_NOT_FOUND,				# Bad file descriptor
	Errno::EL3HLT		=> HTTP_INTERNAL_SERVER_ERROR,			# Level 3 halted
	Errno::E2BIG		=> HTTP_INTERNAL_SERVER_ERROR,			# Argument list too long
	Errno::ENOLINK		=> HTTP_INTERNAL_SERVER_ERROR,			# Link has been severed
	Errno::EALREADY		=> HTTP_INTERNAL_SERVER_ERROR,			# Operation already in progress
	Errno::EREMOTEIO	=> HTTP_BAD_GATEWAY,				# Remote I/O error
	Errno::ERESTART		=> HTTP_INTERNAL_SERVER_ERROR,			# Interrupted system call should be restarted
	Errno::EMSGSIZE		=> HTTP_UNPROCESSABLE_ENTITY,			# Message too long
	Errno::EXDEV		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid cross-device link
	Errno::EIDRM		=> HTTP_INTERNAL_SERVER_ERROR,			# Identifier removed
	Errno::ENAVAIL		=> HTTP_TOO_MANY_REQUESTS,			# No XENIX semaphores available
	Errno::ESPIPE		=> HTTP_INTERNAL_SERVER_ERROR,			# Illegal seek
	Errno::ENAMETOOLONG	=> HTTP_UNPROCESSABLE_ENTITY,			# File name too long
	Errno::ENOSYS		=> HTTP_METHOD_NOT_ALLOWED,			# Function not implemented
	Errno::EOPNOTSUPP	=> HTTP_INTERNAL_SERVER_ERROR,			# Operation not supported
	Errno::ENOSR		=> HTTP_INSUFFICIENT_STORAGE,			# Out of streams resources
	Errno::ENOENT		=> HTTP_NOT_FOUND,				# No such file or directory
	Errno::ENOPKG		=> HTTP_NOT_FOUND,				# Package not installed
	Errno::EACCES		=> HTTP_FORBIDDEN,				# Permission denied
	Errno::ENETUNREACH	=> HTTP_INTERNAL_SERVER_ERROR,			# Network is unreachable
	Errno::ECHRNG		=> HTTP_INTERNAL_SERVER_ERROR,			# Channel number out of range
	Errno::EPROTOTYPE	=> HTTP_INTERNAL_SERVER_ERROR,			# Protocol wrong type for socket
	Errno::ETIMEDOUT	=> HTTP_REQUEST_TIMEOUT,			# Connection timed out
	Errno::EDESTADDRREQ	=> HTTP_INTERNAL_SERVER_ERROR,			# Destination address required
	Errno::EDOM		=> HTTP_INTERNAL_SERVER_ERROR,			# Numerical argument out of domain
	Errno::ESTALE		=> HTTP_FORBIDDEN,				# Stale file handle
	Errno::EL2HLT		=> HTTP_INTERNAL_SERVER_ERROR,			# Level 2 halted
	Errno::ESRCH		=> HTTP_INTERNAL_SERVER_ERROR,			# No such process
	Errno::ENOKEY		=> HTTP_UNAUTHORIZED,				# Required key not available
	Errno::EDEADLK		=> HTTP_CONFLICT,				# Resource deadlock avoided
	Errno::ENFILE		=> HTTP_TOO_MANY_REQUESTS,			# Too many open files in system
	Errno::ELOOP		=> HTTP_INTERNAL_SERVER_ERROR,			# Too many levels of symbolic links
	Errno::ECHILD		=> HTTP_INTERNAL_SERVER_ERROR,			# No child processes
	Errno::EBADMSG		=> HTTP_INTERNAL_SERVER_ERROR,			# Bad message
	Errno::EROFS		=> HTTP_FORBIDDEN,				# Read-only file system
	Errno::EUNATCH		=> HTTP_INTERNAL_SERVER_ERROR,			# Protocol driver not attached
	Errno::ELIBACC		=> HTTP_NOT_FOUND,				# Can not access a needed shared library
	Errno::ENOSPC		=> HTTP_INSUFFICIENT_STORAGE,			# No space left on device
	Errno::EAGAIN		=> HTTP_CONFLICT,				# Resource temporarily unavailable
	Errno::ENOTBLK		=> HTTP_INTERNAL_SERVER_ERROR,			# Block device required
	Errno::EBADSLT		=> HTTP_INTERNAL_SERVER_ERROR,			# Invalid slot
	Errno::ECANCELED	=> HTTP_INTERNAL_SERVER_ERROR,			# Operation canceled
	Errno::EAFNOSUPPORT	=> HTTP_INTERNAL_SERVER_ERROR,			# Address family not supported by protocol
	Errno::EDQUOT		=> HTTP_INSUFFICIENT_STORAGE,			# Disk quota exceeded
	Errno::EADDRINUSE	=> HTTP_INTERNAL_SERVER_ERROR,			# Address already in use
	Errno::EFBIG		=> HTTP_PAYLOAD_TOO_LARGE,			# File too large
	Errno::ENOMSG		=> HTTP_NOT_FOUND,				# No message of desired type
	Errno::ELIBSCN		=> HTTP_INTERNAL_SERVER_ERROR,			# .lib section in a.out corrupted
	Errno::ENODEV		=> HTTP_INTERNAL_SERVER_ERROR,			# No such device
	Errno::ENOLCK		=> HTTP_INSUFFICIENT_STORAGE,			# No locks available
	Errno::EBUSY		=> HTTP_CONFLICT,				# Device or resource busy
	Errno::ENOTSOCK		=> HTTP_INTERNAL_SERVER_ERROR,			# Socket operation on non-socket
);

Readonly my $DEFAULT => HTTP_INTERNAL_SERVER_ERROR;

=head1 ATTRIBUTES

None

=head1 METHODS

=over

=item C<map($error)>

Map a system error such as L<Errno::ENOENT> through to a HTTP error such as C<HTTP_NOT_FOUND>.
All known errors are handled, and if we haven't covered one, on a POSIX derivative which hasn't been
tested, we will return C<HTTP_INTERNAL_SERVER_ERROR>, which seems like a sensible default.

Passing C<0> or C<undef> will always return C<HTTP_OK>.

nb. pass C<int($ERRNO)> because otherwise, the message may be passed, which we can't easily
map back to the integer.  In theory we could but it would be wasteful and might not work if your
locale is not English.

=cut

sub map {
	my ($self, $error) = @_;
	$error //= 0;

	my $mapped;
	if (exists($MAPPINGS{$error})) {
		$mapped = $MAPPINGS{$error};
		$self->dic->logger->debug(sprintf('Mapped error %s -> %s', __errorMsg($error), __statusLine($mapped)));
	} else {
		$mapped = $DEFAULT;
		$self->dic->logger->warn(sprintf('No mapping for error %s, defaulting to %s', __errorMsg($error), __statusLine($mapped)));
	}

	return $mapped;
}

=back

=head1 PRIVATE STATIC FUNCTIONS

=over

=item C<__statusLine($mapped)>

Given the mapped error, which must be an HTTP error code, we will return a loggable status message.
This includes the HTTP constant such as C<HTTP_NOT_FOUND>, the numerical version (404) and the message
"Not Found", for example.

=cut

sub __statusLine {
	my ($mapped) = @_;
	return sprintf('%s %d: %s', status_constant_name($mapped), $mapped, status_message($mapped));
}

=item C<__errorMsg($error)>

Returns the loggable message associated with a system error.  For example, passing C<2> will return
a message including C<2>, C<ENOENT> and C<"No such file or directory">, depending on your locale.

=cut

sub __errorMsg {
	my ($error) = @_;
	return sprintf('%s (%d) %s', __getSymbolicName($error), $error, strerror($error));
}

=item C<__getSymbolicName($error)>

Given C<2>, for example, will return C<ENOENT>.
We have to loop through all of the available errors on the system.

=cut

sub __getSymbolicName {
	my ($error) = @_;

	my $symbolic = '???';

	foreach my $mnemonic (keys(%!)) {
		no strict 'refs';
		$mnemonic = "Errno::$mnemonic";
		$! = &$mnemonic;
		$mnemonic =~ s/^Errno:://;
		my $value = $!{$mnemonic};
		if ($value == $error) {
			$symbolic = $mnemonic;
			last;
		}
	}

	return $symbolic;
}

=back

=cut

__PACKAGE__->meta->make_immutable;

1;
