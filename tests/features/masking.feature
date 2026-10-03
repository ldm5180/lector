Feature: Secrets are masked and bodies escaped, for a log

  A wire body is logged only after the values of its secret keys -- an
  account number, a hash -- are masked, and a body is embedded in a
  JSON log line only after it is escaped.  Masking errs toward masking:
  every occurrence is masked, and so is a value that never ends; a key
  the body does not hold leaves the text as it was.

  Scenario: A quoted value is masked in place, and its neighbours stay
    Given a document:
      """
      {"hashValue":"AB12","id":7}
      """
    When the values of hashValue are masked
    Then the text reads:
      """
      {"hashValue":"***","id":7}
      """

  Scenario: A bare number is masked
    Given a document:
      """
      {"orderId": 100247}
      """
    When the values of orderId are masked
    Then the text reads:
      """
      {"orderId": ***}
      """

  Scenario: Every occurrence is masked
    Given a document:
      """
      {"a":"x","a":"y"}
      """
    When the values of a are masked
    Then the text reads:
      """
      {"a":"***","a":"***"}
      """

  Scenario: A key the body does not hold changes nothing
    Given a document:
      """
      {"other":"x"}
      """
    When the values of absent are masked
    Then the text is unchanged

  Scenario: A value that never ends is still masked
    Given a document:
      """
      {"k":"unterminated
      """
    When the values of k are masked
    Then the text reads:
      """
      {"k":"***
      """

  Scenario: A value that is not a scalar is left alone
    Given a document:
      """
      {"k":null}
      """
    When the values of k are masked
    Then the text is unchanged

  Scenario: Masking twice changes nothing more
    Given a document:
      """
      {"k":"s3cr3t"}
      """
    When the values of k are masked
    Then the text reads:
      """
      {"k":"***"}
      """
    And masking it again changes nothing

  Scenario: Several keys are masked in one pass, in the text's order
    Given a document:
      """
      {"b":1,"a":"x","c":"y"}
      """
    When the values of these keys are masked:
      | a |
      | b |
    Then the text reads:
      """
      {"b":***,"a":"***","c":"y"}
      """
    And masking it again changes nothing

  Scenario: A body with quotes, a backslash and a line break escapes to a JSON string
    Given a document:
      """
      say "hi" \ then
      a new line
      """
    When the document is escaped for a log
    Then the text reads:
      """
      say \"hi\" \\ then\na new line
      """
