//
//  QuizLogicTests.swift
//  quiz_appTests
//
//  Test della logica pura: valutazione risposte, scheduling SM-2, decodifica Scale, merge stats.
//

import XCTest
import SwiftData
@testable import quiz_app

// MARK: - Helpers

private func opt(_ id: Int, _ correct: Bool) -> Option {
    Option(id: id, text: "opt\(id)", isCorrect: correct)
}

private func multipleQuestion(_ options: [Option]) -> Question {
    Question(id: "q", category: "c", subcategory: nil, kind: .multiple, prompt: "p",
             code: nil, explanation: nil, options: options,
             left: nil, right: nil, correctMatches: nil)
}

private func matchingQuestion(_ gold: [Int: Int]) -> Question {
    Question(id: "m", category: "c", subcategory: nil, kind: .matching, prompt: "p",
             code: nil, explanation: nil, options: nil,
             left: ["a", "b"], right: ["1", "2"], correctMatches: gold)
}

// MARK: - Evaluator

final class EvaluatorTests: XCTestCase {

    func testMultipleCorrect_allAndOnlyCorrectSelected() {
        let q = multipleQuestion([opt(0, true), opt(1, false), opt(2, true)])
        XCTAssertEqual(evaluateMultiple(question: q, selected: [0, 2]).result, .correct)
    }

    func testMultipleIncomplete_subsetOfCorrect() {
        let q = multipleQuestion([opt(0, true), opt(1, false), opt(2, true)])
        let detail = evaluateMultiple(question: q, selected: [0])
        XCTAssertEqual(detail.result, .incomplete)
        XCTAssertEqual(detail.missedCorrect, [2])
    }

    func testMultipleWrong_whenWrongOptionPicked() {
        let q = multipleQuestion([opt(0, true), opt(1, false)])
        let detail = evaluateMultiple(question: q, selected: [0, 1])
        XCTAssertEqual(detail.result, .wrong)
        XCTAssertEqual(detail.wrongPicked, [1])
    }

    func testMultipleEmptySelectionIsWrong() {
        let q = multipleQuestion([opt(0, true)])
        XCTAssertEqual(evaluateMultiple(question: q, selected: []).result, .wrong)
    }

    func testMatchingCorrect() {
        XCTAssertEqual(evaluateMatching(question: matchingQuestion([0: 0, 1: 1]),
                                        userPairs: [0: 0, 1: 1]), .correct)
    }

    func testMatchingWrong_onMismatch() {
        XCTAssertEqual(evaluateMatching(question: matchingQuestion([0: 0, 1: 1]),
                                        userPairs: [0: 1]), .wrong)
    }

    func testMatchingIncomplete_partialButCorrect() {
        XCTAssertEqual(evaluateMatching(question: matchingQuestion([0: 0, 1: 1]),
                                        userPairs: [0: 0]), .incomplete)
    }

    func testMatchingEmptyIsWrong() {
        XCTAssertEqual(evaluateMatching(question: matchingQuestion([0: 0]),
                                        userPairs: [:]), .wrong)
    }
}

// MARK: - Nuovi tipi (Fase 1)

/// Crea una domanda minimale del `kind` indicato e applica le personalizzazioni.
private func makeQuestion(_ kind: QuestionKind, _ build: (inout Question) -> Void) -> Question {
    var q = Question(id: "t", category: "c", subcategory: nil, kind: kind, prompt: "p",
                     code: nil, explanation: nil, options: nil,
                     left: nil, right: nil, correctMatches: nil)
    build(&q)
    return q
}

final class TrueFalseMotivatedTests: XCTestCase {
    private func question() -> Question {
        makeQuestion(.trueFalseMotivated) {
            $0.answer = false
            $0.motivationOptions = [opt(0, true), opt(1, false), opt(2, false)]
        }
    }

    func testWrongValueIsWrongRegardlessOfMotivation() {
        XCTAssertEqual(evaluateTrueFalseMotivated(question: question(), answer: true, motivation: [0]), .wrong)
    }

    func testRightValueAndRightMotivationIsCorrect() {
        XCTAssertEqual(evaluateTrueFalseMotivated(question: question(), answer: false, motivation: [0]), .correct)
    }

    func testRightValueWrongMotivationIsWrong() {
        XCTAssertEqual(evaluateTrueFalseMotivated(question: question(), answer: false, motivation: [1]), .wrong)
    }

    func testRightValueEmptyMotivationIsWrong() {
        XCTAssertEqual(evaluateTrueFalseMotivated(question: question(), answer: false, motivation: []), .wrong)
    }

    func testNoMotivationOptionsOnlyValueMatters() {
        let q = makeQuestion(.trueFalseMotivated) { $0.answer = true }
        XCTAssertEqual(evaluateTrueFalseMotivated(question: q, answer: true, motivation: []), .correct)
    }
}

final class ClozeTests: XCTestCase {
    private func question() -> Question {
        makeQuestion(.clozeWordBank) {
            $0.text = "Il metodo {{0}} e {{1}}."
            $0.blanks = [Blank(id: 0, answers: ["GET"]), Blank(id: 1, answers: ["POST"])]
            $0.wordBank = ["GET", "POST", "PUT"]
        }
    }

    func testAllCorrectCaseInsensitive() {
        XCTAssertEqual(evaluateCloze(question: question(), filled: [0: "get", 1: " POST "]).result, .correct)
    }

    func testOneWrongIsWrong() {
        XCTAssertEqual(evaluateCloze(question: question(), filled: [0: "GET", 1: "PUT"]).result, .wrong)
    }

    func testPartialFilledIsIncomplete() {
        let d = evaluateCloze(question: question(), filled: [0: "GET"])
        XCTAssertEqual(d.result, .incomplete)
        XCTAssertEqual(d.missedBlanks, [1])
    }

    func testEmptyIsWrong() {
        XCTAssertEqual(evaluateCloze(question: question(), filled: [:]).result, .wrong)
    }
}

final class ShortAnswerTests: XCTestCase {
    func testCaseInsensitiveSynonymAccepted() {
        let q = makeQuestion(.shortAnswer) { $0.acceptedAnswers = ["Roma", "Rome"] }
        XCTAssertEqual(evaluateShortAnswer(question: q, text: "  rome "), .correct)
    }

    func testCaseSensitiveRejectsDifferentCase() {
        let q = makeQuestion(.shortAnswer) {
            $0.acceptedAnswers = ["GET"]
            $0.caseSensitive = true
        }
        XCTAssertEqual(evaluateShortAnswer(question: q, text: "get"), .wrong)
    }

    func testEmptyIsWrong() {
        let q = makeQuestion(.shortAnswer) { $0.acceptedAnswers = ["x"] }
        XCTAssertEqual(evaluateShortAnswer(question: q, text: "   "), .wrong)
    }
}

final class OrderedTests: XCTestCase {
    private func question() -> Question {
        makeQuestion(.ordered) { $0.items = ["a", "b", "c"] }
    }

    func testExactOrderIsCorrect() {
        XCTAssertEqual(evaluateOrdered(question: question(), userOrder: [0, 1, 2]).result, .correct)
    }

    func testFullyReversedSmallIsWrong() {
        // Con 3 elementi una permutazione può lasciare 0 elementi a posto → wrong.
        XCTAssertEqual(evaluateOrdered(question: question(), userOrder: [1, 2, 0]).result, .wrong)
    }

    func testPartialIsIncomplete() {
        let d = evaluateOrdered(question: question(), userOrder: [0, 2, 1])
        XCTAssertEqual(d.result, .incomplete)
        XCTAssertEqual(d.misplaced, [1, 2])
    }

    func testWrongCountIsWrong() {
        XCTAssertEqual(evaluateOrdered(question: question(), userOrder: [0, 1]).result, .wrong)
    }
}

final class CalculationTests: XCTestCase {
    func testNumericWithinToleranceIsCorrect() {
        let q = makeQuestion(.calculation) {
            $0.acceptedAnswers = ["3.14"]
            $0.tolerance = 0.01
        }
        XCTAssertEqual(evaluateCalculation(question: q, text: "3.15"), .correct)
    }

    func testNumericOutsideToleranceIsWrong() {
        let q = makeQuestion(.calculation) {
            $0.acceptedAnswers = ["3.14"]
            $0.tolerance = 0.01
        }
        XCTAssertEqual(evaluateCalculation(question: q, text: "3.20"), .wrong)
    }

    func testCommaDecimalIsParsed() {
        let q = makeQuestion(.calculation) {
            $0.acceptedAnswers = ["10"]
            $0.tolerance = 0.5
        }
        XCTAssertEqual(evaluateCalculation(question: q, text: "10,2"), .correct)
    }

    func testStringFallbackWithoutTolerance() {
        let q = makeQuestion(.calculation) { $0.acceptedAnswers = ["O(n log n)"] }
        XCTAssertEqual(evaluateCalculation(question: q, text: "o(n log n)"), .correct)
    }
}

// MARK: - Validazione nuovi tipi

final class ValidationNewTypesTests: XCTestCase {
    private let taxonomy = [Materia.Node(id: "c", name: "C", sub: nil)]

    private func validate(_ q: Question) throws {
        let materia = Materia(
            meta: .init(subject_id: "auto:sha256", subject_name: "S", version: 1),
            config: .init(scales_questions: [.all], scales_category: [.all],
                          scales_errors: [.all], feedback: "immediate"),
            taxonomy: taxonomy,
            questions: [q]
        )
        let data = try JSONEncoder().encode(materia)
        _ = try validateMateriaData(data)
    }

    func testValidTrueFalseMotivatedPasses() throws {
        let q = makeQuestion(.trueFalseMotivated) {
            $0.id = "q1"; $0.answer = false
            $0.motivationOptions = [opt(0, true), opt(1, false)]
        }
        XCTAssertNoThrow(try validate(q))
    }

    func testTrueFalseMissingAnswerThrows() throws {
        let q = makeQuestion(.trueFalseMotivated) { $0.id = "q1" }
        XCTAssertThrowsError(try validate(q))
    }

    func testClozeMissingPlaceholderThrows() throws {
        let q = makeQuestion(.clozeWordBank) {
            $0.id = "q1"
            $0.text = "Solo {{0}}."
            $0.blanks = [Blank(id: 0, answers: ["A"]), Blank(id: 1, answers: ["B"])]
            $0.wordBank = ["A", "B"]
        }
        XCTAssertThrowsError(try validate(q))
    }

    func testClozeAnswerNotInBankThrows() throws {
        let q = makeQuestion(.clozeWordBank) {
            $0.id = "q1"
            $0.text = "{{0}}"
            $0.blanks = [Blank(id: 0, answers: ["Z"])]
            $0.wordBank = ["A", "B"]
        }
        XCTAssertThrowsError(try validate(q))
    }

    func testShortAnswerMissingAcceptedThrows() throws {
        let q = makeQuestion(.shortAnswer) { $0.id = "q1" }
        XCTAssertThrowsError(try validate(q))
    }

    func testOrderedNeedsAtLeastTwoItems() throws {
        let q = makeQuestion(.ordered) { $0.id = "q1"; $0.items = ["solo"] }
        XCTAssertThrowsError(try validate(q))
    }

    func testCalculationValidPasses() throws {
        let q = makeQuestion(.calculation) {
            $0.id = "q1"; $0.acceptedAnswers = ["42"]; $0.tolerance = 0
        }
        XCTAssertNoThrow(try validate(q))
    }
}

// MARK: - Fase 2: dispatcher, aggregazione, formativi

final class DispatcherTests: XCTestCase {
    func testDispatchMultiple() {
        let q = multipleQuestion([opt(0, true), opt(1, false)])
        var input = AnswerInput(); input.selectedOptions = [0]
        XCTAssertEqual(evaluate(q, input: input), .correct)
    }

    func testDispatchShortAnswer() {
        let q = makeQuestion(.shortAnswer) { $0.acceptedAnswers = ["roma"] }
        var input = AnswerInput(); input.text = "Roma"
        XCTAssertEqual(evaluate(q, input: input), .correct)
    }

    func testDispatchTrueFalseNilAnswerIsWrong() {
        let q = makeQuestion(.trueFalseMotivated) { $0.answer = true }
        XCTAssertEqual(evaluate(q, input: AnswerInput()), .wrong)
    }
}

final class AggregateTests: XCTestCase {
    func testAllCorrect() { XCTAssertEqual(aggregateResults([.correct, .correct]), .correct) }
    func testAllWrong() { XCTAssertEqual(aggregateResults([.wrong, .wrong]), .wrong) }
    func testMixedIsIncomplete() { XCTAssertEqual(aggregateResults([.correct, .wrong]), .incomplete) }
    func testEmptyIsIncomplete() { XCTAssertEqual(aggregateResults([]), .incomplete) }
}

final class FormativeFlagTests: XCTestCase {
    func testOpenRubricIsFormative() {
        XCTAssertTrue(makeQuestion(.openRubric) { $0.keyPoints = ["x"] }.isFormative)
    }

    func testCaseStudyWithScoredSubIsNotFormative() {
        let sub = multipleQuestion([opt(0, true)])
        let q = makeQuestion(.caseStudy) { $0.subquestions = [sub] }
        XCTAssertFalse(q.isFormative)
    }

    func testCaseStudyAllFormativeSubsIsFormative() {
        let sub = makeQuestion(.openRubric) { $0.id = "s"; $0.keyPoints = ["x"] }
        let q = makeQuestion(.caseStudy) { $0.subquestions = [sub] }
        XCTAssertTrue(q.isFormative)
    }
}

final class ValidationPhase2Tests: XCTestCase {
    private let taxonomy = [Materia.Node(id: "c", name: "C", sub: nil)]

    private func validate(_ q: Question) throws {
        let materia = Materia(
            meta: .init(subject_id: "auto:sha256", subject_name: "S", version: 1),
            config: .init(scales_questions: [.all], scales_category: [.all],
                          scales_errors: [.all], feedback: "immediate"),
            taxonomy: taxonomy,
            questions: [q]
        )
        _ = try validateMateriaData(try JSONEncoder().encode(materia))
    }

    func testOpenRubricNeedsExpectedOrKeyPoints() {
        let q = makeQuestion(.openRubric) { $0.id = "q1" }
        XCTAssertThrowsError(try validate(q))
    }

    func testOpenRubricValidPasses() {
        let q = makeQuestion(.openRubric) { $0.id = "q1"; $0.keyPoints = ["a", "b"]; $0.minKeyPoints = 1 }
        XCTAssertNoThrow(try validate(q))
    }

    func testConstructedResponseNeedsRequiredCriteria() {
        let q = makeQuestion(.constructedResponse) { $0.id = "q1" }
        XCTAssertThrowsError(try validate(q))
    }

    func testMediaAnalysisNeedsMediaAndSub() {
        let q = makeQuestion(.mediaAnalysis) { $0.id = "q1" }
        XCTAssertThrowsError(try validate(q))
    }

    func testMediaAnalysisValidPasses() {
        let sub = makeQuestion(.shortAnswer) { $0.id = "s1"; $0.prompt = "p"; $0.acceptedAnswers = ["x"] }
        let q = makeQuestion(.mediaAnalysis) {
            $0.id = "q1"
            $0.media = MediaAsset(type: .image, url: "https://example.com/a.png")
            $0.subquestions = [sub]
        }
        XCTAssertNoThrow(try validate(q))
    }

    func testCaseStudyRejectsNestedComposite() {
        let nested = makeQuestion(.caseStudy) { $0.id = "n"; $0.prompt = "p"; $0.subquestions = [] }
        let q = makeQuestion(.caseStudy) { $0.id = "q1"; $0.subquestions = [nested] }
        XCTAssertThrowsError(try validate(q))
    }

    func testCaseStudyValidPasses() {
        let s1 = makeQuestion(.multiple) { $0.id = "s1"; $0.prompt = "p"; $0.options = [opt(0, true), opt(1, false)] }
        let s2 = makeQuestion(.shortAnswer) { $0.id = "s2"; $0.prompt = "p"; $0.acceptedAnswers = ["ok"] }
        let q = makeQuestion(.caseStudy) {
            $0.id = "q1"
            $0.stimuli = [Stimulus(id: "st1", text: "Contesto")]
            $0.subquestions = [s1, s2]
        }
        XCTAssertNoThrow(try validate(q))
    }
}

// MARK: - Fase 3: pool randomizzato di opzioni

/// RNG deterministico (SplitMix64) per test riproducibili.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private func poolEntry(_ id: String, _ concept: String, correct: Bool, _ variant: PoolVariantKind? = nil) -> PoolEntry {
    PoolEntry(id: id, text: "Frase \(id) sufficientemente lunga e plausibile", isCorrect: correct,
              canonicalPointId: concept, variantKind: variant)
}

/// Pool: 6 concetti corretti, 10 concetti errati; display 4, corrette 1..3.
private func makePool(displayCount: Int = 4, min: Int = 1, max: Int = 3,
                      allowDup: Bool? = nil) -> AnswerOptionPool {
    var entries: [PoolEntry] = []
    for i in 0..<6 { entries.append(poolEntry("c\(i)", "concept_c\(i)", correct: true, .correctParaphrase)) }
    for i in 0..<10 { entries.append(poolEntry("w\(i)", "concept_w\(i)", correct: false, .tooAbsolute)) }
    return AnswerOptionPool(displayCount: displayCount,
                            correctCountRange: CountRange(min: min, max: max),
                            entries: entries, allowDuplicateConcepts: allowDup)
}

final class PoolResolverTests: XCTestCase {

    func testSampleHasExactlyDisplayCount() {
        var rng = SeededGenerator(seed: 1)
        let sample = PoolSampler.sample(makePool(), using: &rng)
        XCTAssertEqual(sample?.count, 4)
    }

    func testCorrectCountWithinRange() {
        for seed in UInt64(0)..<50 {
            var rng = SeededGenerator(seed: seed)
            let sample = PoolSampler.sample(makePool(), using: &rng) ?? []
            let correct = sample.filter { $0.isCorrect }.count
            XCTAssertGreaterThanOrEqual(correct, 1)
            XCTAssertLessThanOrEqual(correct, 3)
        }
    }

    func testSampleStableForSameSeed() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let s1 = PoolSampler.sample(makePool(), using: &a)?.map { $0.id }
        let s2 = PoolSampler.sample(makePool(), using: &b)?.map { $0.id }
        XCTAssertEqual(s1, s2)
    }

    func testSampleDiffersAcrossSeeds() {
        // Su molti semi, almeno una coppia deve differire (campione non statico).
        var sets: Set<[String]> = []
        for seed in UInt64(0)..<20 {
            var rng = SeededGenerator(seed: seed)
            if let ids = PoolSampler.sample(makePool(), using: &rng)?.map({ $0.id }).sorted() { sets.insert(ids) }
        }
        XCTAssertGreaterThan(sets.count, 1)
    }

    func testNoDuplicateConceptInSample() {
        for seed in UInt64(0)..<50 {
            var rng = SeededGenerator(seed: seed)
            let sample = PoolSampler.sample(makePool(), using: &rng) ?? []
            let concepts = sample.map { $0.canonicalPointId }
            XCTAssertEqual(concepts.count, Set(concepts).count, "Concetti duplicati nel campione (seed \(seed))")
        }
    }

    func testAllowDuplicateConceptsRelaxesUniqueness() {
        // Pool con un solo concetto corretto ma più entry: con allowDup deve poter campionare.
        var entries = [poolEntry("c0", "k", correct: true), poolEntry("c1", "k", correct: true)]
        for i in 0..<5 { entries.append(poolEntry("w\(i)", "wk\(i)", correct: false)) }
        let pool = AnswerOptionPool(displayCount: 3, correctCountRange: CountRange(min: 2, max: 2),
                                    entries: entries, allowDuplicateConcepts: true)
        var rng = SeededGenerator(seed: 3)
        let sample = PoolSampler.sample(pool, using: &rng)
        XCTAssertEqual(sample?.count, 3)
        XCTAssertEqual(sample?.filter { $0.isCorrect }.count, 2)
    }
}

final class PoolEvaluationTests: XCTestCase {
    private let shown = [
        PoolEntry(id: "a", text: "A", isCorrect: true, canonicalPointId: "ka"),
        PoolEntry(id: "b", text: "B", isCorrect: true, canonicalPointId: "kb"),
        PoolEntry(id: "c", text: "C", isCorrect: false, canonicalPointId: "kc", variantKind: .tooAbsolute)
    ]

    func testCorrectOnlyWhenAllAndOnlyCorrectShownSelected() {
        XCTAssertEqual(evaluatePoolSelection(shown: shown, selected: ["a", "b"]).result, .correct)
    }

    func testWrongWhenWrongSelected() {
        let d = evaluatePoolSelection(shown: shown, selected: ["a", "c"])
        XCTAssertEqual(d.result, .wrong)
        XCTAssertEqual(d.wrongConcepts, ["kc"])
        XCTAssertEqual(d.wrongVariants, [.tooAbsolute])
    }

    func testIncompleteWhenSubsetOfCorrect() {
        let d = evaluatePoolSelection(shown: shown, selected: ["a"])
        XCTAssertEqual(d.result, .incomplete)
        XCTAssertEqual(d.missedConcepts, ["kb"])
    }

    func testEmptyIsWrong() {
        XCTAssertEqual(evaluatePoolSelection(shown: shown, selected: []).result, .wrong)
    }

    func testIgnoresEntriesNotShown() {
        // "z" non è tra le mostrate: deve essere ignorata, quindi a+b resta corretto.
        XCTAssertEqual(evaluatePoolSelection(shown: shown, selected: ["a", "b", "z"]).result, .correct)
    }
}

final class PoolValidationTests: XCTestCase {
    func testValidPoolHasNoError() {
        XCTAssertNil(PoolSampler.validationError(makePool()))
    }

    func testDisplayCountMustBePositive() {
        XCTAssertEqual(PoolSampler.validationError(makePool(displayCount: 0)), .displayCountNotPositive)
    }

    func testRangeMinGreaterThanMaxFails() {
        XCTAssertEqual(PoolSampler.validationError(makePool(min: 3, max: 1)), .invalidRange)
    }

    func testNotEnoughCorrectConcepts() {
        // min 5 corrette ma displayCount 4 → invalidRange (min > displayCount) scatta prima.
        let err = PoolSampler.validationError(makePool(displayCount: 4, min: 5, max: 5))
        XCTAssertEqual(err, .invalidRange)
    }

    func testPoolTooSmallForDisplayCount() {
        // 4 concetti distinti, range 0..5 (vincoli su corrette/errate soddisfatti),
        // ma displayCount 5 > 4 concetti → impossibile per unicità concettuale.
        var entries = [poolEntry("c0", "k0", correct: true), poolEntry("c1", "k1", correct: true)]
        entries.append(poolEntry("w0", "k2", correct: false))
        entries.append(poolEntry("w1", "k3", correct: false))
        let pool = AnswerOptionPool(displayCount: 5, correctCountRange: CountRange(min: 0, max: 5), entries: entries)
        if case .poolTooSmall = PoolSampler.validationError(pool) {} else {
            XCTFail("Atteso .poolTooSmall, ottenuto \(String(describing: PoolSampler.validationError(pool)))")
        }
    }

    func testNotEnoughWrongConceptsReported() {
        // 3 concetti distinti, displayCount 5, min1 max1 → servono 4 errate ma ce ne sono 2.
        var entries = [poolEntry("c0", "k0", correct: true)]
        entries.append(poolEntry("w0", "k1", correct: false))
        entries.append(poolEntry("w1", "k2", correct: false))
        let pool = AnswerOptionPool(displayCount: 5, correctCountRange: CountRange(min: 1, max: 1), entries: entries)
        if case .notEnoughWrongConcepts = PoolSampler.validationError(pool) {} else {
            XCTFail("Atteso .notEnoughWrongConcepts, ottenuto \(String(describing: PoolSampler.validationError(pool)))")
        }
    }

    func testDuplicateEntryIdFails() {
        var entries = makePool().entries
        entries.append(poolEntry("c0", "concept_x", correct: true)) // id "c0" duplicato
        let pool = AnswerOptionPool(displayCount: 4, correctCountRange: CountRange(min: 1, max: 3), entries: entries)
        XCTAssertEqual(PoolSampler.validationError(pool), .duplicateEntryId("c0"))
    }

    func testEmptyCanonicalPointIdFails() {
        var entries = makePool().entries
        entries.append(PoolEntry(id: "x", text: "testo", isCorrect: false, canonicalPointId: ""))
        let pool = AnswerOptionPool(displayCount: 4, correctCountRange: CountRange(min: 1, max: 3), entries: entries)
        XCTAssertEqual(PoolSampler.validationError(pool), .emptyCanonicalPointId("x"))
    }
}

@MainActor
final class PoolStatsTests: XCTestCase {
    func testApplyPoolDeltaRecordsConceptsAndVariants() throws {
        let container = try ModelContainer(
            for: QuestionProgress.self, StudySession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let store = StudyDataStore(context: context, subjectId: "s")

        let q = makeQuestion(.trueFalseMotivated) { $0.id = "q1"; $0.answer = false }
        let detail = PoolEvalDetail(result: .wrong,
                                    missedConcepts: ["ka"],
                                    wrongConcepts: ["kc"],
                                    wrongVariants: [.tooAbsolute])
        store.applyPoolDelta(for: q, detail: detail)

        let fetched = try context.fetch(FetchDescriptor<QuestionProgress>()).first
        XCTAssertEqual(fetched?.wrong, 1)
        XCTAssertEqual(fetched?.conceptStats["ka"]?.missedCorrect, 1)
        XCTAssertEqual(fetched?.conceptStats["kc"]?.wrongSelected, 1)
        XCTAssertEqual(fetched?.variantWrong["tooAbsolute"], 1)
    }
}

// MARK: - Spaced repetition (SM-2)

final class SpacedRepetitionTests: XCTestCase {

    func testCorrectFirstRepetition() {
        let s = SpacedRepetition.next(easeFactor: 2.5, intervalDays: 0, repetitions: 0, result: .correct)
        XCTAssertEqual(s.repetitions, 1)
        XCTAssertEqual(s.intervalDays, 1)
        XCTAssertGreaterThan(s.easeFactor, 2.5, "q=5 deve aumentare l'ease factor")
    }

    func testCorrectSecondRepetitionIntervalIsSix() {
        let s = SpacedRepetition.next(easeFactor: 2.5, intervalDays: 1, repetitions: 1, result: .correct)
        XCTAssertEqual(s.intervalDays, 6)
        XCTAssertEqual(s.repetitions, 2)
    }

    func testCorrectThirdRepetitionUsesEaseFactor() {
        let s = SpacedRepetition.next(easeFactor: 2.5, intervalDays: 6, repetitions: 2, result: .correct)
        XCTAssertEqual(s.intervalDays, 15) // round(6 * 2.5): l'intervallo usa l'EF corrente
        XCTAssertEqual(s.repetitions, 3)
    }

    func testWrongResetsRepetitionsAndInterval() {
        let s = SpacedRepetition.next(easeFactor: 2.5, intervalDays: 30, repetitions: 5, result: .wrong)
        XCTAssertEqual(s.repetitions, 0)
        XCTAssertEqual(s.intervalDays, 1)
    }

    func testIncompleteAdvancesButLowersEase() {
        let s = SpacedRepetition.next(easeFactor: 2.5, intervalDays: 6, repetitions: 2, result: .incomplete)
        XCTAssertLessThan(s.easeFactor, 2.5, "q=3 deve abbassare l'ease factor")
        XCTAssertGreaterThanOrEqual(s.intervalDays, 6)
    }

    func testEaseFactorNeverBelowFloor() {
        var ef = 1.3
        for _ in 0..<10 {
            ef = SpacedRepetition.next(easeFactor: ef, intervalDays: 1, repetitions: 0, result: .wrong).easeFactor
        }
        XCTAssertGreaterThanOrEqual(ef, 1.3)
    }

    func testDueDateIsInFuture() {
        let now = Date()
        let s = SpacedRepetition.next(easeFactor: 2.5, intervalDays: 0, repetitions: 0, result: .correct, now: now)
        XCTAssertGreaterThan(s.dueDate, now)
    }
}

// MARK: - Scale decoding

final class ScaleTests: XCTestCase {

    func testDecodeIntScale() throws {
        let s = try JSONDecoder().decode(Scale.self, from: Data("10".utf8))
        XCTAssertEqual(s, .count(10))
    }

    func testDecodeAllScaleFromString() throws {
        let s = try JSONDecoder().decode(Scale.self, from: Data("\"all\"".utf8))
        XCTAssertEqual(s, .all)
    }

    func testEncodeRoundTrip() throws {
        let data = try JSONEncoder().encode(Scale.count(42))
        let decoded = try JSONDecoder().decode(Scale.self, from: data)
        XCTAssertEqual(decoded, .count(42))
    }
}

// MARK: - Stats merging

final class StatsMergingTests: XCTestCase {

    func testQuestionStatsMerging() {
        let a = QuestionStats(attempts: 1, correct: 1, incomplete: 0, wrong: 0)
        let b = QuestionStats(attempts: 2, correct: 0, incomplete: 1, wrong: 1)
        let merged = a.merging(with: b)
        XCTAssertEqual(merged.attempts, 3)
        XCTAssertEqual(merged.correct, 1)
        XCTAssertEqual(merged.incomplete, 1)
        XCTAssertEqual(merged.wrong, 1)
    }

    func testStatsFileMergingSumsCategoryWrong() {
        var a = StatsFile(subject_id: "s")
        a.per_category_wrong["cat"] = 2
        var b = StatsFile(subject_id: "s")
        b.per_category_wrong["cat"] = 3
        let merged = a.merging(with: b)
        XCTAssertEqual(merged.per_category_wrong["cat"], 5)
    }
}
