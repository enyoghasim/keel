import type { UserEvent } from '@testing-library/user-event'
import { screen } from '@testing-library/react'

/** Opens a shadcn Select (a Radix combobox) and picks an option by its visible name. */
export async function chooseOption(user: UserEvent, trigger: HTMLElement, optionName: string | RegExp) {
  await user.click(trigger)
  await user.click(await screen.findByRole('option', { name: optionName }))
}
