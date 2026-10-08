import { IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class SwitchWorkspaceDto {
  @IsString()
  @MinLength(2)
  @MaxLength(48)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  workspaceSlug!: string;
}

