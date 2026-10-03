Feature: A document is one complete object, or it is not

  Before a file on disk is parsed, a consumer asks whether it is one
  complete object with nothing after it.  The parse cannot answer: it
  stops at the first complete value and accepts what follows.  A file
  cut short, written twice or wrapped in stray bytes is caught here.

  Scenario: A plain object is a single object
    Given a document:
      """
      {"a": 1}
      """
    When the document is checked for a single object
    Then the document is a single object

  Scenario: Blank lines after the object are fine
    Given a document:
      """
      {"a": 1}


      """
    When the document is checked for a single object
    Then the document is a single object

  Scenario: Bytes after the object are not
    Given a document:
      """
      {"a": 1}garbage
      """
    When the document is checked for a single object
    Then the document is not a single object

  Scenario: A file cut short is not
    Given a document:
      """
      {"a": 1, "b
      """
    When the document is checked for a single object
    Then the document is not a single object

  Scenario: An object written twice is not
    Given a document:
      """
      {"a": 1}{"a": 2}
      """
    When the document is checked for a single object
    Then the document is not a single object

  Scenario: Bytes before the object are not
    Given a document:
      """
      x{"a": 1}
      """
    When the document is checked for a single object
    Then the document is not a single object

  Scenario: Braces inside a string are text
    Given a document:
      """
      {"note": "a } and a { and an escaped \" quote"}
      """
    When the document is checked for a single object
    Then the document is a single object

  Scenario: An empty document is not
    Given an empty document
    When the document is checked for a single object
    Then the document is not a single object

  Scenario: What the parse accepts, the single-object check refuses
    Given a document:
      """
      {"a": "1"}trailing
      """
    When the document is parsed
    Then the parse succeeds
    When the document is checked for a single object
    Then the document is not a single object
