import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-success-toast',
  standalone: true,
  templateUrl: './success-toast.component.html',
  styleUrl: './success-toast.component.scss'
})
export class SuccessToastComponent {
  @Input({ required: true }) message = '';
}
