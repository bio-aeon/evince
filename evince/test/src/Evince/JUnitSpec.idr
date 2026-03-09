module Evince.JUnitSpec

import Data.String
import Evince
import Evince.Report
import Evince.Reporter.JUnit

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
      renderXml [] `mustSatisfy` (isInfixOf "<?xml version=\"1.0\"")

    it "includes testsuite element with counts" $ do
      let xml = renderXml [passedReport, failedReport, skippedReport]
      xml `mustSatisfy` (isInfixOf "tests=\"3\"")
      xml `mustSatisfy` (isInfixOf "failures=\"1\"")
      xml `mustSatisfy` (isInfixOf "skipped=\"1\"")

    it "renders passing test as self-closing testcase" $
      renderXml [passedReport] `mustSatisfy`
        (isInfixOf "testcase name=\"passes\" classname=\"Suite\" time=\"0.003\"/>")

    it "renders failing test with failure element" $
      renderXml [failedReport] `mustSatisfy` (isInfixOf "<failure message=\"boom\"/>")

    it "renders skipped test with skipped element" $
      renderXml [skippedReport] `mustSatisfy` (isInfixOf "<skipped message=\"todo\"/>")

    it "escapes special characters in test names" $ do
      let report = MkTestReport ["A&B", "x < y"] (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (isInfixOf "classname=\"A&amp;B\"")
      xml `mustSatisfy` (isInfixOf "name=\"x &lt; y\"")

    it "uses dot-joined describe path as classname" $ do
      let report = MkTestReport ["Outer", "Inner", "test name"] (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (isInfixOf "classname=\"Outer.Inner\"")
      xml `mustSatisfy` (isInfixOf "name=\"test name\"")
