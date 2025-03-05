package org.chlebsearch.util;

import java.util.Arrays;
import java.util.List;

/**
 * Parser boolean values in {@link String} format into simple boolean values.
 * This class is designed for parsing values within URIs and from config files.
 */
public class BooleanParser {

	/**
	 * known true values; a fixed list.
	 */
	private static final List<String> TRUE_VALUES = Arrays.asList("1", "true", "on", "yes");

	/**
	 * known false values; a fixed list.
	 */
	private static final List<String> FALSE_VALUES = Arrays.asList("0", "false", "off", "no");

	/**
	 * isTrue returns true iff v is a known-true value.
	 *
	 * @param v String
	 * @return boolean
	 */
	private static boolean isTrue(String v) {
		for (final String trueValue : TRUE_VALUES) {
			if (v.equals(trueValue)) return true;
		}

		if (v.startsWith("enable")) return true;

		return false;
	}

	/**
	 * isFalse returns true iff v is a known-false value.
	 *
	 * @param v String
	 * @return boolean
	 */
	private static boolean isFalse(String v) {
		for (final String falseValue : FALSE_VALUES) {
			if (v.equals(falseValue)) return true;
		}

		if (v.startsWith("disable")) return true;

		return false;
	}

	/**
	 * Parse a user-supplied config boolean into a simple type.
	 *
	 * The value may be null or anything supplied by the user, without sanity checking,
	 * if the value is recognized from one of the known values: true/false, 1/0,
	 * enabled/disabled, on/off, yes/no and so on, we return a simple scalar value.
	 *
	 * If the value is null and a default value is specified, that default will be returned.
	 * If no default is specified, the value is considered mandatory and {@link BooleanParserUserException} is
	 * thrown.  If the default is not properly specified and not null, we throw {@link BooleanParserSystemException},
	 * which means you need to fix your code.
	 *
	 * @param key String
	 * @param value String
	 * @param defaultValue String
	 * @return boolean
	 * @throws BooleanParserUserException
	 * @throws BooleanParserSystemException
	 */
	public static boolean parse(final String key, String value, String defaultValue) throws BooleanParserException {
		boolean defaultValueReturned = false;

		// Let's run this block first so we trap invalid defaults even when they aren't used
		if (defaultValue != null) {
			defaultValue = defaultValue.toLowerCase();
			if (isTrue(defaultValue)) {
				defaultValueReturned = true;
			} else if (!isFalse(defaultValue)) {
				throw new BooleanParserSystemException(key, String.format(
					"Illegal default value: '%s' for key '%s'",
					defaultValue,
					key
				));
			}
		}

		if (value != null) {
			value = value.trim();
			if (value.length() > 0) {
				value = value.toLowerCase();

				if (isTrue(value)) return true;
				if (isFalse(value)) return false;

				throw new BooleanParserUserException(key, String.format(
					"Illegal user-supplied value: '%s' for key '%s'",
					value,
					key
				));
			}
		}

		if (defaultValue != null) return defaultValueReturned; // Apply default, if supplied/available
		throw new BooleanParserUserException(key, String.format("Mandatory value for key '%s' not supplied", key));
	}

	/**
	 * See {@link #parse(final String key, String value, String defaultValue)}.
	 * This method is for the convenience of users who do not want to supply a default.
	 *
	 * @param key String
	 * @param value String
	 * @return boolean
	 * @throws BooleanParserUserException
	 * @throws BooleanParserSystemException
	 */
	public static boolean parse(final String key, final String value) throws BooleanParserException {
		return parse(key, value, null);
	}
}
