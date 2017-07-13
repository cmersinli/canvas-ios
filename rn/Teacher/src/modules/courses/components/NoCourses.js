/**
 * @flow
 */

import React, { Component } from 'react'
import {
  View,
  StyleSheet,
} from 'react-native'
import i18n from 'format-message'
import { Text } from '../../../common/text'
import { Button } from '../../../common/buttons'
import colors from '../../../common/colors'

type Props = {
  onAddCoursePressed: () => void,
}

export class NoCourses extends Component {
  props: Props

  render () {
    let welcome = i18n('Welcome!')

    let bodyText = i18n('Add a few of your favorite courses to make this place your home.')

    let buttonText = i18n('Add Courses')

    return (
      <View style={styles.container}>
        <Text style={styles.welcome} testID='no-courses.welcome-lbl'>{welcome}</Text>
        <Text
          style={styles.paragraph} testID='no-courses.description-lbl'>{bodyText}</Text>
        <Button
          accessibilityLabel={buttonText}
          testID='no-courses.add-courses-btn'
          onPress={this.props.onAddCoursePressed}
          style={styles.button}
          containerStyle={styles.buttonContainer}
        >
          {buttonText}
        </Button>
      </View>
    )
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 40,
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
  },
  welcome: {
    fontSize: 30,
    lineHeight: 36,
    color: colors.darkText,
    marginBottom: 8,
  },
  paragraph: {
    textAlign: 'center',
    color: colors.grey4,
    fontSize: 16,
    lineHeight: 19,
    paddingHorizontal: 10,
    marginBottom: 40,
  },
  button: {
    fontSize: 16,
    lineHeight: 19,
  },
  buttonContainer: {
    borderRadius: 4,
    paddingHorizontal: 24,
    paddingVertical: 16,
  },
})

export default (NoCourses: any)
