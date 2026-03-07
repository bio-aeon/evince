module Evince.JUnitSpec

import Data.String
import Evince
import Evince.Report
import Evince.Reporter.JUnit

contains : String -> String -> Bool
contains haystack needle = isInfixOf needle haystack

passedReport : TestReport
passedReport = MkTestReport ["Suite", "passes"] (Passed 3000000)

failedReport : TestReport
failedReport = MkTestReport ["Suite", "fails"] (Failed (Reason "boom") 1000000)

skippedReport : TestReport
skippedReport = MkTestReport ["Suite", "skipped"] (Skipped (Just "todo"))

export
junitSpec : Spec () ()
junitSpec = describe "JUnit XML" $ do
  describe "renderXml" $ do
    it "includes XML declaration" $
      renderXml [] `mustSatisfy` (`contains` "<?xml version=\"1.0\"")

    it "includes testsuite element with counts" $ do
      let xml = renderXml [passedReport, failedReport, skippedReport]
      xml `mustSatisfy` (`contains` "tests=\"3\"")
      xml `mustSatisfy` (`contains` "failures=\"1\"")
      xml `mustSatisfy` (`contains` "skipped=\"1\"")

    it "renders passing test as self-closing testcase" $
      renderXml [passedReport] `mustSatisfy`
        (`contains` "testcase name=\"passes\" classname=\"Suite\" time=\"0.003\"/>")

    it "renders failing test with failure element" $
      renderXml [failedReport] `mustSatisfy` (`contains` "<failure message=\"boom\"/>")

    it "renders skipped test with skipped element" $
      renderXml [skippedReport] `mustSatisfy` (`contains` "<skipped message=\"todo\"/>")

    it "escapes special characters in test names" $ do
      let report = MkTestReport ["A&B", "x < y"] (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (`contains` "classname=\"A&amp;B\"")
      xml `mustSatisfy` (`contains` "name=\"x &lt; y\"")

    it "uses dot-joined describe path as classname" $ do
      let report = MkTestReport ["Outer", "Inner", "test name"] (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (`contains` "classname=\"Outer.Inner\"")
      xml `mustSatisfy` (`contains` "name=\"test name\"")
