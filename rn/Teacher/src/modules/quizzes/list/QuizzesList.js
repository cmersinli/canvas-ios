/**
* Launching pad for navigation for a single course
* @flow
*/

import React, { Component } from 'react'
import { connect } from 'react-redux'
import {
  View,
  StyleSheet,
  SectionList,
  NativeModules,
} from 'react-native'
import i18n from 'format-message'

import Actions from './actions'
import refresh from '../../../utils/refresh'
import QuizRow from './QuizRow'
import SectionHeader from '../../../common/components/rows/SectionHeader'
import Screen from '../../../routing/Screen'
import { type TraitCollection } from '../../../routing/Navigator'
import { isRegularDisplayMode } from '../../../routing/utils'
import ActivityIndicatorView from '../../../common/components/ActivityIndicatorView'

const { NativeAccessibility } = NativeModules

type OwnProps = {
  courseID: string,
}

type State = {
  quizzes: Quiz[],
  courseColor: ?string,
  pending: boolean,
}

export type Props = State & typeof Actions & {
  navigator: Navigator,
}

const HEADERS = {
  'assignment': i18n('Assignments'),
  'practice_quiz': i18n('Practice Quiz'),
  'graded_survey': i18n('Graded Survey'),
  'survey': i18n('Survey'),
}

export class QuizzesList extends Component<any, Props, any> {
  isRegularScreenDisplayMode: boolean
  didSelectFirstItem = false
  data: any = []

  componentWillReceiveProps (nextProps: Props) {
    if (nextProps.quizzes.length) {
      NativeAccessibility.refresh()
    }
  }

  onTraitCollectionChange () {
    this.props.navigator.traitCollection((traits) => { this.traitCollectionDidChange(traits) })
  }

  traitCollectionDidChange (traits: TraitCollection) {
    this.isRegularScreenDisplayMode = isRegularDisplayMode(traits)
    if (!this.isRegularScreenDisplayMode) {
      this.didSelectFirstItem = false
    }
    this.selectFirstListItemIfNecessary()
  }

  selectFirstListItemIfNecessary () {
    let firstQuiz = this._firstQuizInList()
    if (!this.didSelectFirstItem && this.isRegularScreenDisplayMode && firstQuiz) {
      this._selectedQuiz(firstQuiz)
      this.didSelectFirstItem = true
    }
  }

  _firstQuizInList (): ?Quiz {
    if (this.data.length > 0 && this.data[0].data.length > 0) {
      let quiz = this.data[0].data[0]
      return quiz
    }
    return null
  }

  renderRow = ({ item, index }: { item: Quiz, index: number }) => {
    let selected = this.isRegularScreenDisplayMode && this.props.selectedRowID === item.id
    return (
      <QuizRow
        quiz={item}
        index={index}
        tintColor={this.props.courseColor}
        onPress={this._selectedQuiz}
        selected={selected}
      />
    )
  }

  renderSectionHeader = ({ section }: any) => {
    return <SectionHeader title={HEADERS[section.key]} key={section.key} top={section.index === 0} />
  }

  _selectedQuiz = (quiz: Quiz) => {
    this.props.updateCourseDetailsSelectedTabSelectedRow(quiz.id)
    this.props.navigator.show(quiz.html_url)
  }

  _getData = () => {
    const sections = this.props.quizzes
      .reduce((data, quiz) => ({
        ...data,
        [quiz.quiz_type]: (data[quiz.quiz_type] || []).concat([quiz]),
      }), {})

    return Object.keys(sections).map((key, index) => {
      return {
        index,
        key,
        data: this._sortSectionByKey(sections[key], key),
      }
    })
  }

  _sortSectionByKey (section: Quiz[], key: string): Array<Quiz> {
    const sortBy = key === 'assignment' ? 'due_at' : 'lock_at'
    return section.sort((a, b) => {
      const tieBreaker = a.title.toLowerCase() < b.title.toLowerCase() ? -1 : 1
      if (!a[sortBy] && !b[sortBy]) {
        return tieBreaker
      }
      if (!a[sortBy]) {
        return 1
      }
      if (!b[sortBy]) {
        return -1
      }
      const x = new Date(a[sortBy]) < new Date(b[sortBy]) ? -1 : 1
      return x === 0 ? tieBreaker : x
    })
  }

  render () {
    if (this.props.pending && !this.props.refreshing) {
      return <ActivityIndicatorView />
    }

    if (this.data.length === 0) {
      this.data = this._getData()
      this.selectFirstListItemIfNecessary()
    }

    return (
      <Screen
        navBarColor={this.props.courseColor}
        navBarStyle='dark'
        drawUnderNavBar={true}
        title={i18n('Quizzes')}
        onTraitCollectionChange={this.onTraitCollectionChange.bind(this)}
        subtitle={this.props.courseName}>
        <View style={styles.container}>
          <SectionList
            sections={this.data}
            renderSectionHeader={this.renderSectionHeader}
            renderItem={this.renderRow}
            refreshing={Boolean(this.props.pending)}
            onRefresh={this.props.refresh}
            keyExtractor={(item, index) => item.id}
            testID='quiz-list.list'
          />
        </View>
      </Screen>
    )
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    marginBottom: global.tabBarHeight,
  },
})

export function mapStateToProps ({ entities }: AppState, { courseID }: OwnProps): State {
  let quizzes = []
  let courseColor = null
  let courseName = null
  let pending = false
  let selectedRowID = entities.courseDetailsTabSelectedRow.rowID || ''

  if (entities &&
    entities.courses &&
    entities.courses[courseID] &&
    entities.courses[courseID].quizzes &&
    entities.quizzes) {
    const course = entities.courses[courseID]
    const refs = course.quizzes.refs
    quizzes = refs
      .map(ref => entities.quizzes[ref].data)
    courseColor = course.color
    courseName = course.course.name
    pending = !!course.quizzes.pending
  }

  return {
    pending,
    quizzes,
    courseColor,
    courseName,
    selectedRowID,
  }
}

const Refreshed = refresh(
  props => {
    props.refreshQuizzes(props.courseID)
  },
  props => props.quizzes.length === 0,
  props => Boolean(props.pending)
)(QuizzesList)
const Connected = connect(mapStateToProps, Actions)(Refreshed)
export default (Connected: Component<any, Props, any>)
