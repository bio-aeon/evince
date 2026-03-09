module Evince.JUnitSpec

import Data.String
import Evince
import Evince.Report
import Evince.Reporter.JUnit

passedReport : TestReport
passedReport = MkTestReport ["Suite", "passes"] Nothing (Passed 3000000)

failedReport : TestReport
failedReport = MkTestReport ["Suite", "fails"] Nothing (Failed (Reason "boom") 1000000)

skippedReport : TestReport
skippedReport = MkTestReport ["Suite", "skipped"] Nothing (Skipped (Just "todo"))

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
      let report = MkTestReport ["A&B", "x < y"] Nothing (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (isInfixOf "classname=\"A&amp;B\"")
      xml `mustSatisfy` (isInfixOf "name=\"x &lt; y\"")

    it "uses dot-joined describe path as classname" $ do
      let report = MkTestReport ["Outer", "Inner", "test name"] Nothing (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (isInfixOf "classname=\"Outer.Inner\"")
      xml `mustSatisfy` (isInfixOf "name=\"test name\"")

    it "includes file and line when SrcLoc is present" $ do
      let loc = MkSrcLoc "Test/Module" 9 0
      let report = MkTestReport ["Suite", "located"] (Just loc) (Passed 0)
      let xml = renderXml [report]
      xml `mustSatisfy` (isInfixOf "file=\"Test/Module\"")
      xml `mustSatisfy` (isInfixOf "line=\"10\"")

    it "omits file and line when SrcLoc is absent" $
      renderXml [passedReport] `mustNotSatisfy` (isInfixOf "file=")
